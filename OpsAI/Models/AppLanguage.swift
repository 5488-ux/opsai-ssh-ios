import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}
