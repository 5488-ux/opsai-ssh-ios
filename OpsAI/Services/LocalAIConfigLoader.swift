import Foundation

struct LocalAIConfigLoader {
    struct LocalAIConfig: Decodable {
        let providerName: String?
        let baseURL: String?
        let model: String?
        let apiKey: String?
    }

    static func load() -> LocalAIConfig? {
        guard let url = Bundle.main.url(forResource: "LocalAIConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(LocalAIConfig.self, from: data)
    }
}
