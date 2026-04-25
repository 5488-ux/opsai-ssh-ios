import Foundation

struct AppIssueEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let source: String
    let message: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        source: String,
        message: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.message = message
        self.createdAt = createdAt
    }

    var copyText: String {
        """
        来源：\(source)
        时间：\(createdAt.formatted(date: .abbreviated, time: .shortened))
        内容：\(message)
        """
    }
}
