import Foundation

struct SSHServer: Identifiable, Codable, Equatable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case port
        case username
        case serverSize
        case boundDomains
        case authenticationMethod
        case passwordReference
        case privateKeyReference
        case lastConnectedAt
        case notes
    }

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
    var serverSize: String
    var boundDomains: String
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
        serverSize: String = "",
        boundDomains: String = "",
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
        self.serverSize = serverSize
        self.boundDomains = boundDomains
        self.authenticationMethod = authenticationMethod
        self.passwordReference = passwordReference
        self.privateKeyReference = privateKeyReference
        self.lastConnectedAt = lastConnectedAt
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 22
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        serverSize = try container.decodeIfPresent(String.self, forKey: .serverSize) ?? ""
        boundDomains = try container.decodeIfPresent(String.self, forKey: .boundDomains) ?? ""
        authenticationMethod = try container.decodeIfPresent(AuthenticationMethod.self, forKey: .authenticationMethod) ?? .password
        passwordReference = try container.decodeIfPresent(String.self, forKey: .passwordReference)
        privateKeyReference = try container.decodeIfPresent(String.self, forKey: .privateKeyReference)
        lastConnectedAt = try container.decodeIfPresent(Date.self, forKey: .lastConnectedAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    var displayTitle: String {
        name.isEmpty ? host : name
    }

    var boundDomainList: [String] {
        boundDomains
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " || $0 == "，" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var normalizedForSaving: SSHServer {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.serverSize = serverSize.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.boundDomains = boundDomains
            .split(whereSeparator: { $0 == "\n" || $0 == "，" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return copy
    }
}
