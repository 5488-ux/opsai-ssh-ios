import Foundation
import SSHClient

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
    case unsupportedAuthenticationMethod
    case remoteError(String)
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "Missing SSH credential."
        case .notConnected:
            return "SSH session is not connected."
        case .unsupportedAuthenticationMethod:
            return "Private key login is not wired yet. Use password authentication for the first real SSH build."
        case .remoteError(let message):
            return message
        case .invalidPort:
            return "SSH port is invalid."
        }
    }
}

final class RealSSHService: SSHServiceProtocol {
    private var connection: SSHConnection?

    func connect(using request: SSHConnectionRequest) async throws {
        if connection != nil {
            await disconnect()
        }

        switch request.server.authenticationMethod {
        case .password:
            guard let password = request.password, !password.isEmpty else {
                throw SSHServiceError.missingCredential
            }
            guard let port = UInt16(exactly: request.server.port) else {
                throw SSHServiceError.invalidPort
            }

            let connection = SSHConnection(
                host: request.server.host,
                port: port,
                authentication: SSHAuthentication(
                    username: request.server.username,
                    method: .password(.init(password)),
                    hostKeyValidation: .acceptAll()
                )
            )

            try await start(connection)
            self.connection = connection
        case .privateKey:
            throw SSHServiceError.unsupportedAuthenticationMethod
        }
    }

    func disconnect() async {
        guard let connection else { return }
        await withCheckedContinuation { continuation in
            connection.cancel {
                continuation.resume()
            }
        }
        self.connection = nil
    }

    func execute(_ command: String) async throws -> String {
        guard let connection else {
            throw SSHServiceError.notConnected
        }

        let response = try await run(command, on: connection)
        let stdout = String(data: response.standardOutput ?? Data(), encoding: .utf8) ?? ""
        let stderr = String(data: response.errorOutput ?? Data(), encoding: .utf8) ?? ""

        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        if response.status.exitStatus != 0 {
            throw SSHServiceError.remoteError(
                combined.isEmpty
                    ? "Command failed with exit status \(response.status.exitStatus)."
                    : combined
            )
        }

        return combined.isEmpty ? "$ \(command)\n(exit 0)" : "$ \(command)\n\(combined)"
    }

    private func start(_ connection: SSHConnection) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.start { result in
                continuation.resume(with: result)
            }
        }
    }

    private func run(_ command: String, on connection: SSHConnection) async throws -> SSHCommandResponse {
        try await withCheckedThrowingContinuation { continuation in
            connection.execute(SSHCommand(command)) { result in
                continuation.resume(with: result)
            }
        }
    }
}
