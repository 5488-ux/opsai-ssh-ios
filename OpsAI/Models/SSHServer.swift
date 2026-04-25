import Foundation

struct SSHServer: Identifiable, Codable, Equatable, Hashable {
    enum AuthenticationMethod: String, Codable, CaseIterable, Identifiable, Hashable {
        case password
        case privateKey

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .password:
                return "密码"
            case .privateKey:
                return "私钥"
            }
        }
    }

    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authenticationMethod: AuthenticationMethod
    var passwordReference: String?
    var privateKeyReference: String?
    var lastConnectedAt: Date?
    var notes: String

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 22,
        username: String = "",
        authenticationMethod: AuthenticationMethod = .password,
        passwordReference: String? = nil,
        privateKeyReference: String? = nil,
        lastConnectedAt: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authenticationMethod = authenticationMethod
        self.passwordReference = passwordReference
        self.privateKeyReference = privateKeyReference
        self.lastConnectedAt = lastConnectedAt
        self.notes = notes
    }

    var displayTitle: String {
        name.isEmpty ? host : name
    }

    var normalizedForSaving: SSHServer {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
