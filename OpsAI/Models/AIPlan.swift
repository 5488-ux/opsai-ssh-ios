import Foundation

struct AIPlan: Identifiable, Codable, Equatable {
    struct CommandDraft: Identifiable, Codable, Equatable {
        enum RiskLevel: String, Codable, CaseIterable, Identifiable {
            case low
            case medium
            case high

            var id: String { rawValue }

            var displayName: String {
                switch self {
                case .low:
                    return "低风险"
                case .medium:
                    return "中风险"
                case .high:
                    return "高风险"
                }
            }
        }

        var id: UUID
        var command: String
        var reason: String
        var riskLevel: RiskLevel
        var requiresApproval: Bool
        var approvedAt: Date?
        var output: String?

        init(
            id: UUID = UUID(),
            command: String,
            reason: String,
            riskLevel: RiskLevel,
            requiresApproval: Bool = true,
            approvedAt: Date? = nil,
            output: String? = nil
        ) {
            self.id = id
            self.command = command
            self.reason = reason
            self.riskLevel = riskLevel
            self.requiresApproval = requiresApproval
            self.approvedAt = approvedAt
            self.output = output
        }
    }

    var id: UUID
    var userGoal: String
    var summary: String
    var commands: [CommandDraft]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userGoal: String,
        summary: String,
        commands: [CommandDraft],
        createdAt: Date = .now
    ) {
        self.id = id
        self.userGoal = userGoal
        self.summary = summary
        self.commands = commands
        self.createdAt = createdAt
    }
}
