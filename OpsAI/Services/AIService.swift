import Foundation

struct AIOpsAssistantResponse: Equatable {
    let reply: String
    let plan: AIPlan?
}

protocol AIServiceProtocol {
    func askAssistant(
        prompt: String,
        history: [AIOpsChatMessage],
        server: SSHServer,
        assistantProfile: AIAssistantProfile,
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> AIOpsAssistantResponse

    func testConnection(
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> String
}

enum AIServiceError: LocalizedError {
    case invalidBaseURL
    case missingAPIKey
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "AI 接口地址无效。"
        case .missingAPIKey:
            return "AI 接口密钥未填写。"
        case .requestFailed(let message):
            return message
        case .invalidResponse:
            return "AI 返回内容无法解析。"
        }
    }
}

final class AIService: AIServiceProtocol {
    func askAssistant(
        prompt: String,
        history: [AIOpsChatMessage],
        server: SSHServer,
        assistantProfile: AIAssistantProfile,
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> AIOpsAssistantResponse {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedKey.isEmpty else {
            let plan = fallbackPlan(goal: prompt, server: server)
            return AIOpsAssistantResponse(
                reply: "当前还没有配置 AI 接口密钥。我先给你一份本地只读排查计划，你可以先按这些命令检查。",
                plan: plan
            )
        }

        guard let endpoint = makeEndpointURL(from: config.baseURL, suffix: "/chat/completions") else {
            throw AIServiceError.invalidBaseURL
        }

        let contextLines = history.suffix(6).map { message in
            switch message.role {
            case .user:
                return "用户：\(message.text)"
            case .assistant:
                return "助手：\(message.text)"
            }
        }

        let requestBody = DeepSeekChatRequest(
            model: config.model,
            response_format: .init(type: "json_object"),
            messages: [
                .init(
                    role: "system",
                    content: [
                        assistantProfile.systemPrompt,
                        config.systemPrompt,
                        "你是对话式运维助手。",
                        "你必须只返回 JSON 对象。",
                        "返回格式必须是：",
                        "{\"reply\":\"字符串\",\"summary\":\"字符串\",\"commands\":[{\"command\":\"字符串\",\"reason\":\"字符串\",\"riskLevel\":\"low|medium|high\"}]}",
                        "reply 是给用户的自然语言回答，要求简洁明确。",
                        "summary 是命令计划摘要，如果暂时不需要命令也要简短说明。",
                        "commands 数量限制为 0 到 4 条。",
                        "优先生成只读命令。",
                        "不要返回 markdown 代码块。",
                        "riskLevel 只能是 low、medium、high。"
                    ].joined(separator: "\n")
                ),
                .init(
                    role: "user",
                    content: [
                        "目标服务器：\(server.username)@\(server.host):\(server.port)",
                        contextLines.isEmpty ? "历史对话：无" : "历史对话：\n" + contextLines.joined(separator: "\n"),
                        "本次问题：\(prompt)"
                    ].joined(separator: "\n\n")
                )
            ],
            temperature: 0.2
        )

        let data = try await sendRequest(
            url: endpoint,
            method: "POST",
            providerName: config.providerName,
            apiKey: trimmedKey,
            body: requestBody
        )

        let completion = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let rawContent = completion.choices.first?.message.content,
              !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.invalidResponse
        }

        let payloadData = Data(stripCodeFences(from: rawContent).utf8)
        let payload = try JSONDecoder().decode(DeepSeekAssistantPayload.self, from: payloadData)

        let plan: AIPlan?
        if payload.commands.isEmpty {
            plan = nil
        } else {
            plan = AIPlan(
                userGoal: prompt,
                summary: payload.summary,
                commands: payload.commands.prefix(4).map {
                    AIPlan.CommandDraft(
                        command: $0.command,
                        reason: $0.reason,
                        riskLevel: $0.riskLevel,
                        requiresApproval: config.requireApprovalPerCommand
                    )
                }
            )
        }

        return AIOpsAssistantResponse(reply: payload.reply, plan: plan)
    }

    func testConnection(
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> String {
        guard let endpoint = makeEndpointURL(from: config.baseURL, suffix: "/models") else {
            throw AIServiceError.invalidBaseURL
        }

        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let data = try await sendRequest(
            url: endpoint,
            method: "GET",
            providerName: config.providerName,
            apiKey: trimmedKey,
            body: Optional<EmptyBody>.none
        )

        let modelList = try JSONDecoder().decode(DeepSeekModelsResponse.self, from: data)
        let modelIDs = modelList.data.map(\.id)

        guard !modelIDs.isEmpty else {
            return "API 测试成功，但服务端没有返回模型列表。"
        }

        if modelIDs.contains(config.model) {
            return "API 测试成功。当前模型 \(config.model) 可用。"
        }

        let preview = modelIDs.prefix(5).joined(separator: "、")
        return "API 已连通，但当前模型 \(config.model) 不在返回列表中。可用模型示例：\(preview)"
    }

    private func sendRequest<Body: Encodable>(
        url: URL,
        method: String,
        providerName: String,
        apiKey: String,
        body: Body?
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(data: data, response: response, providerName: providerName)
        return data
    }

    private func validateHTTPResponse(data: Data, response: URLResponse, providerName: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.requestFailed("AI 请求失败：未收到有效的 HTTP 响应。")
        }

        if !(200...299).contains(httpResponse.statusCode) {
            if let apiError = try? JSONDecoder().decode(DeepSeekErrorResponse.self, from: data),
               let message = apiError.error?.message,
               !message.isEmpty {
                throw AIServiceError.requestFailed("\(providerName) 请求失败：\(message)")
            }
            throw AIServiceError.requestFailed("\(providerName) 请求失败：HTTP \(httpResponse.statusCode)。")
        }
    }

    private func makeEndpointURL(from baseURL: String, suffix: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }

        if trimmed.hasSuffix("/chat/completions") {
            trimmed = String(trimmed.dropLast("/chat/completions".count))
        }

        if trimmed.hasSuffix("/models") {
            trimmed = String(trimmed.dropLast("/models".count))
        }

        return URL(string: trimmed + suffix)
    }

    private func stripCodeFences(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else {
            return trimmed
        }

        let lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 3 else {
            return trimmed
        }

        return lines
            .dropFirst()
            .dropLast()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallbackPlan(goal: String, server: SSHServer) -> AIPlan {
        AIPlan(
            userGoal: goal,
            summary: "当前还没有配置 AI 接口密钥，所以 OpsAI 为 \(server.host) 生成了一份本地只读排查计划。",
            commands: [
                .init(
                    command: "hostname",
                    reason: "确认当前连接到的是哪台服务器。",
                    riskLevel: .low
                ),
                .init(
                    command: "whoami",
                    reason: "确认远端当前登录账号。",
                    riskLevel: .low
                ),
                .init(
                    command: "ps aux | head",
                    reason: "先只读查看当前进程概况，不修改系统状态。",
                    riskLevel: .low
                )
            ]
        )
    }
}

private struct EmptyBody: Encodable {}

private struct DeepSeekChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let response_format: ResponseFormat
    let messages: [Message]
    let temperature: Double
}

private struct DeepSeekChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct DeepSeekErrorResponse: Decodable {
    struct Payload: Decodable {
        let message: String?
    }

    let error: Payload?
}

private struct DeepSeekModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}

private struct DeepSeekAssistantPayload: Decodable {
    struct Command: Decodable {
        let command: String
        let reason: String
        let riskLevel: AIPlan.CommandDraft.RiskLevel
    }

    let reply: String
    let summary: String
    let commands: [Command]
}
