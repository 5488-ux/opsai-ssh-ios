import Foundation

struct AIProviderConfig: Codable, Equatable {
    var providerName: String
    var baseURL: String
    var model: String
    var apiKeyReference: String?
    var systemPrompt: String
    var requireApprovalPerCommand: Bool

    static let `default` = AIProviderConfig(
        providerName: "OpenAI-Compatible",
        baseURL: "https://api.openai.com/v1",
        model: "gpt-5.4",
        apiKeyReference: nil,
        systemPrompt: """
        You are an infrastructure assistant inside an iPhone SSH tool.
        Produce a short investigation summary and then propose shell commands.
        Never assume permission to execute commands.
        Prefer safe read-only commands first.
        """,
        requireApprovalPerCommand: true
    )
}
