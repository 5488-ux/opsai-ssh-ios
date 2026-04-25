import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var servers: [SSHServer]
    @Published var providerConfig: AIProviderConfig

    private let storage: AppStorageService
    private let keychain: KeychainStore

    init(
        storage: AppStorageService = AppStorageService(),
        keychain: KeychainStore = KeychainStore()
    ) {
        self.storage = storage
        self.keychain = keychain
        self.servers = storage.loadServers()
        self.providerConfig = storage.loadProviderConfig()
    }

    func upsertServer(
        _ server: SSHServer,
        password: String?,
        privateKey: String?
    ) throws {
        if let password, let reference = server.passwordReference {
            try keychain.save(secret: password, account: reference)
        }

        if let privateKey, let reference = server.privateKeyReference {
            try keychain.save(secret: privateKey, account: reference)
        }

        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
        } else {
            servers.append(server)
        }
        servers.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        storage.saveServers(servers)
    }

    func deleteServer(_ server: SSHServer) {
        servers.removeAll { $0.id == server.id }
        if let passwordReference = server.passwordReference {
            keychain.deleteSecret(account: passwordReference)
        }
        if let privateKeyReference = server.privateKeyReference {
            keychain.deleteSecret(account: privateKeyReference)
        }
        storage.saveServers(servers)
    }

    func secret(for reference: String?) -> String? {
        guard let reference else { return nil }
        return keychain.loadSecret(account: reference)
    }

    func saveProviderConfig(_ config: AIProviderConfig, apiKey: String?) throws {
        if let apiKeyReference = config.apiKeyReference, let apiKey {
            try keychain.save(secret: apiKey, account: apiKeyReference)
        }
        providerConfig = config
        storage.saveProviderConfig(config)
    }

    func providerAPIKey() -> String? {
        secret(for: providerConfig.apiKeyReference)
    }
}
