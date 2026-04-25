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
            return "AI base URL is invalid."
        case .missingAPIKey:
            return "AI API key is missing."
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
            summary: "Start with low-risk inspection on \(server.host), then confirm service state and recent logs before proposing any write action.",
            commands: [
                .init(
                    command: "uname -a",
                    reason: "Confirm the host and kernel before deeper troubleshooting.",
                    riskLevel: .low
                ),
                .init(
                    command: "uptime",
                    reason: "Check system load and recent uptime.",
                    riskLevel: .low
                ),
                .init(
                    command: "df -h",
                    reason: "Verify disk pressure before investigating service failures.",
                    riskLevel: .low
                )
            ]
        )
    }

    private func fallbackPlan(goal: String, server: SSHServer) -> AIPlan {
        AIPlan(
            userGoal: goal,
            summary: "No API key is configured yet, so OpsAI generated a local safe-read inspection plan for \(server.host).",
            commands: [
                .init(
                    command: "hostname",
                    reason: "Verify which server you are connected to.",
                    riskLevel: .low
                ),
                .init(
                    command: "whoami",
                    reason: "Check the active remote account.",
                    riskLevel: .low
                ),
                .init(
                    command: "ps aux | head",
                    reason: "Inspect the current process surface without changing state.",
                    riskLevel: .low
                )
            ]
        )
    }
}
