import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ServerListView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles.rectangle.stack")
                }
        }
    }
}
