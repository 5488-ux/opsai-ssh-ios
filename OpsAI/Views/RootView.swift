import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ServerListView()
                .tabItem {
                    Label("服务器", systemImage: "server.rack")
                }

            AISettingsView()
                .tabItem {
                    Label("AI 设置", systemImage: "sparkles.rectangle.stack")
                }
        }
    }
}
