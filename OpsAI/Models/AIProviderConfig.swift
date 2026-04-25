import Foundation

struct AIProviderConfig: Codable, Equatable {
    var providerName: String
    var baseURL: String
    var model: String
    var apiKeyReference: String?
    var systemPrompt: String
    var requireApprovalPerCommand: Bool

    static let `default` = AIProviderConfig(
        providerName: "OpenAI 兼容接口",
        baseURL: "https://api.openai.com/v1",
        model: "gpt-5.4",
        apiKeyReference: nil,
        systemPrompt: """
        你是 iPhone SSH 工具里的运维助手。
        先给出简短排查摘要，再提出 shell 命令建议。
        不要假设自己有执行权限。
        优先给出安全的只读命令。
        """,
        requireApprovalPerCommand: true
    )
}
