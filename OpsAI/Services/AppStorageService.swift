import Foundation

final class AppStorageService {
    private enum Keys {
        static let servers = "opsai.savedServers"
        static let provider = "opsai.providerConfig"
        static let issues = "opsai.issueEntries"
        static let language = "opsai.appLanguage"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.outputFormatting = [.prettyPrinted]
    }

    func loadServers() -> [SSHServer] {
        guard let data = defaults.data(forKey: Keys.servers),
              let servers = try? decoder.decode([SSHServer].self, from: data) else {
            return []
        }
        return servers
    }

    func saveServers(_ servers: [SSHServer]) {
        guard let data = try? encoder.encode(servers) else { return }
        defaults.set(data, forKey: Keys.servers)
    }

    func loadProviderConfig() -> AIProviderConfig {
        guard let data = defaults.data(forKey: Keys.provider),
              let config = try? decoder.decode(AIProviderConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func saveProviderConfig(_ config: AIProviderConfig) {
        guard let data = try? encoder.encode(config) else { return }
        defaults.set(data, forKey: Keys.provider)
    }

    func loadIssueEntries() -> [AppIssueEntry] {
        guard let data = defaults.data(forKey: Keys.issues),
              let issues = try? decoder.decode([AppIssueEntry].self, from: data) else {
            return []
        }
        return issues
    }

    func saveIssueEntries(_ issues: [AppIssueEntry]) {
        guard let data = try? encoder.encode(issues) else { return }
        defaults.set(data, forKey: Keys.issues)
    }

    func loadLanguage() -> AppLanguage {
        guard let rawValue = defaults.string(forKey: Keys.language),
              let language = AppLanguage(rawValue: rawValue) else {
            return .english
        }
        return language
    }

    func saveLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Keys.language)
    }
}
