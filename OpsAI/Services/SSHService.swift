import Foundation

struct SSHConnectionRequest {
    let server: SSHServer
    let password: String?
    let privateKey: String?
}

protocol SSHServiceProtocol {
    func connect(using request: SSHConnectionRequest) async throws
    func disconnect() async
    func execute(_ command: String) async throws -> String
}

enum SSHServiceError: LocalizedError {
    case missingCredential
    case notConnected
    case unavailable

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "Missing SSH credential."
        case .notConnected:
            return "SSH session is not connected."
        case .unavailable:
            return "The production SSH engine is not connected yet."
        }
    }
}

final class MockSSHService: SSHServiceProtocol {
    private var activeServer: SSHServer?

    func connect(using request: SSHConnectionRequest) async throws {
        switch request.server.authenticationMethod {
        case .password:
            guard !(request.password ?? "").isEmpty else {
                throw SSHServiceError.missingCredential
            }
        case .privateKey:
            guard !(request.privateKey ?? "").isEmpty else {
                throw SSHServiceError.missingCredential
            }
        }

        try await Task.sleep(for: .milliseconds(450))
        activeServer = request.server
    }

    func disconnect() async {
        activeServer = nil
    }

    func execute(_ command: String) async throws -> String {
        guard activeServer != nil else {
            throw SSHServiceError.notConnected
        }

        try await Task.sleep(for: .milliseconds(350))
        return """
        $ \(command)
        mock-output: command completed on device-side prototype session.
        """
    }
}
