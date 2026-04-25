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
    case invalidHost
    case invalidUsername

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "缺少 SSH 凭证。"
        case .notConnected:
            return "SSH 会话尚未连接。"
        case .unsupportedAuthenticationMethod:
            return "当前版本暂不支持私钥登录，请改用密码登录。"
        case .remoteError(let message):
            return message
        case .invalidPort:
            return "SSH 端口无效。"
        case .invalidHost:
            return "主机地址不能为空。"
        case .invalidUsername:
            return "用户名不能为空。"
        }
    }
}

final class RealSSHService: SSHServiceProtocol {
    private var connection: SSHConnection?

    func connect(using request: SSHConnectionRequest) async throws {
        if connection != nil {
            await disconnect()
        }

        let host = request.server.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = request.server.username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else {
            throw SSHServiceError.invalidHost
        }

        guard !username.isEmpty else {
            throw SSHServiceError.invalidUsername
        }

        switch request.server.authenticationMethod {
        case .password:
            guard let password = request.password, !password.isEmpty else {
                throw SSHServiceError.missingCredential
            }
            guard let port = UInt16(exactly: request.server.port) else {
                throw SSHServiceError.invalidPort
            }

            var authentication = SSHAuthentication(
                username: username,
                method: .password(.init(password)),
                hostKeyValidation: .acceptAll()
            )
            // Broaden cipher compatibility for servers that still require AES-CTR.
            authentication.transportProtection.schemes = [.bundled, .aes128CTR]

            let connection = SSHConnection(
                host: host,
                port: port,
                authentication: authentication
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
                    ? "命令执行失败，退出码 \(response.status.exitStatus)。"
                    : combined
            )
        }

        return combined.isEmpty ? "$ \(command)\n(退出码 0)" : "$ \(command)\n\(combined)"
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
