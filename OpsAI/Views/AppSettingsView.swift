import SwiftUI

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "5"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Language") {
                    Picker("App Language", selection: Binding(
                        get: { appStore.language },
                        set: { appStore.updateLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }

                Section("Announcements") {
                    Label("OpsAI v1.5 updates the Settings center to English and keeps iOS 26 SDK CI compatibility.", systemImage: "megaphone")
                    Text("OpsAI still connects directly to your servers. AI drafts suggestions and command plans, but it never runs commands automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Release Notes") {
                    updateRow(version: "v1.5", items: [
                        "Converted the Settings center content to English",
                        "Kept the app version and build information visible",
                        "Prepared CI for iOS 26 SDK builds"
                    ])

                    updateRow(version: "v1.4", items: [
                        "Added the top-right Settings entry",
                        "Added announcements, release notes, and version details",
                        "Added the GitHub repository link and app introduction"
                    ])

                    updateRow(version: "v1.3", items: [
                        "Added the App Icon",
                        "Restored the light system interface",
                        "Simplified the workbench information hierarchy"
                    ])
                }

                Section("Version") {
                    LabeledContent("Current Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }

                Section("Links") {
                    Link(destination: URL(string: "https://github.com/5488-ux/opsai-ssh-ios")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                }

                Section("About") {
                    Text("OpsAI is an iPhone SSH operations app. You can save servers, connect directly to terminals, ask AI to draft troubleshooting plans, and manually approve each command before execution.")
                        .font(.body)

                    Label("No backend. Server credentials stay in the local keychain.", systemImage: "lock.shield")
                    Label("Configurable AI provider with OpenAI-compatible APIs.", systemImage: "sparkles")
                    Label("Every AI command draft requires manual approval.", systemImage: "checkmark.shield")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func updateRow(version: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(version)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
