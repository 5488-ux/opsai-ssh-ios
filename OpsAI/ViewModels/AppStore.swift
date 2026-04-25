import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var servers: [SSHServer]
    @Published var providerConfig: AIProviderConfig
    @Published var issueEntries: [AppIssueEntry]

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
        self.issueEntries = storage.loadIssueEntries()

        if providerConfig.apiKeyReference == nil {
            providerConfig.apiKeyReference = AIProviderConfig.defaultAPIKeyReference
        }

        bootstrapLocalAIConfigIfNeeded()
    }

    func upsertServer(
        _ server: SSHServer,
        password: String?,
        privateKey: String?
    ) throws {
        let normalizedServer = server.normalizedForSaving

        if let password, let reference = normalizedServer.passwordReference {
            try keychain.save(secret: password, account: reference)
        }

        if let privateKey, let reference = normalizedServer.privateKeyReference {
            try keychain.save(secret: privateKey, account: reference)
        }

        if let index = servers.firstIndex(where: { $0.id == normalizedServer.id }) {
            servers[index] = normalizedServer
        } else {
            servers.append(normalizedServer)
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
        var updatedConfig = config
        if updatedConfig.apiKeyReference == nil {
            updatedConfig.apiKeyReference = AIProviderConfig.defaultAPIKeyReference
        }

        if let apiKeyReference = updatedConfig.apiKeyReference {
            let trimmedAPIKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedAPIKey.isEmpty {
                keychain.deleteSecret(account: apiKeyReference)
            } else {
                try keychain.save(secret: trimmedAPIKey, account: apiKeyReference)
            }
        }

        providerConfig = updatedConfig
        storage.saveProviderConfig(updatedConfig)
    }

    func providerAPIKey() -> String? {
        secret(for: providerConfig.apiKeyReference)
    }

    func recordIssue(_ message: String, source: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, !trimmedSource.isEmpty else { return }

        let entry = AppIssueEntry(source: trimmedSource, message: trimmedMessage)
        issueEntries.insert(entry, at: 0)
        issueEntries = Array(issueEntries.prefix(50))
        storage.saveIssueEntries(issueEntries)
    }

    func clearIssueEntries() {
        issueEntries = []
        storage.saveIssueEntries(issueEntries)
    }

    func updateBoundDomains(for serverID: UUID, domains: [String]) {
        guard let index = servers.firstIndex(where: { $0.id == serverID }) else { return }
        let normalizedDomains = domains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        servers[index].boundDomains = normalizedDomains.joined(separator: ", ")
        storage.saveServers(servers)
    }

    private func bootstrapLocalAIConfigIfNeeded() {
        guard let localConfig = LocalAIConfigLoader.load() else {
            return
        }

        var updatedConfig = providerConfig
        if let providerName = localConfig.providerName, !providerName.isEmpty {
            updatedConfig.providerName = providerName
        }
        if let baseURL = localConfig.baseURL, !baseURL.isEmpty {
            updatedConfig.baseURL = baseURL
        }
        if let model = localConfig.model, !model.isEmpty {
            updatedConfig.model = model
        }
        if updatedConfig.apiKeyReference == nil {
            updatedConfig.apiKeyReference = AIProviderConfig.defaultAPIKeyReference
        }

        if let apiKey = localConfig.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !apiKey.isEmpty,
           let reference = updatedConfig.apiKeyReference,
           keychain.loadSecret(account: reference) == nil {
            try? keychain.save(secret: apiKey, account: reference)
        }

        if updatedConfig != providerConfig {
            providerConfig = updatedConfig
            storage.saveProviderConfig(updatedConfig)
        }
    }
}
