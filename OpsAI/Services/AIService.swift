import Foundation

protocol AIServiceProtocol {
    func buildPlan(
        goal: String,
        server: SSHServer,
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> AIPlan
}

enum AIServiceError: LocalizedError {
    case invalidBaseURL
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "AI 接口地址无效。"
        case .missingAPIKey:
            return "AI 接口密钥未填写。"
        }
    }
}

final class AIService: AIServiceProtocol {
    func buildPlan(
        goal: String,
        server: SSHServer,
        config: AIProviderConfig,
        apiKey: String?
    ) async throws -> AIPlan {
        guard URL(string: config.baseURL) != nil else {
            throw AIServiceError.invalidBaseURL
        }

        guard let apiKey, !apiKey.isEmpty else {
            return fallbackPlan(goal: goal, server: server)
        }

        _ = apiKey
        try await Task.sleep(for: .milliseconds(700))

        return AIPlan(
            userGoal: goal,
            summary: "先对 \(server.host) 做低风险检查，再确认服务状态和最近日志，最后再决定是否需要写入类操作。",
            commands: [
                .init(
                    command: "uname -a",
                    reason: "先确认目标主机和内核信息，再继续深入排查。",
                    riskLevel: .low
                ),
                .init(
                    command: "uptime",
                    reason: "查看系统负载和最近运行时长。",
                    riskLevel: .low
                ),
                .init(
                    command: "df -h",
                    reason: "先确认磁盘是否存在压力，再判断服务异常原因。",
                    riskLevel: .low
                )
            ]
        )
    }

    private func fallbackPlan(goal: String, server: SSHServer) -> AIPlan {
        AIPlan(
            userGoal: goal,
            summary: "当前还没有配置 API Key，所以 OpsAI 为 \(server.host) 生成了一份本地只读排查计划。",
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
