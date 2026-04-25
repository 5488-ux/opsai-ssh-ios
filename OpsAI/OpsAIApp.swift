import SwiftUI

@main
struct OpsAIApp: App {
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appStore)
                .environment(\.locale, Locale(identifier: appStore.language.localeIdentifier))
        }
    }
}
