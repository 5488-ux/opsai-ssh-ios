import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var config: AIProviderConfig
    @State private var apiKey = ""
    @State private var errorMessage: String?

    init() {
        _config = State(initialValue: .default)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    TextField("Provider name", text: $config.providerName)
                    TextField("Base URL", text: $config.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Model", text: $config.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API key", text: $apiKey)
                }

                Section("Behavior") {
                    Toggle("Require approval for every command", isOn: $config.requireApprovalPerCommand)
                    TextField("System prompt", text: $config.systemPrompt, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Interaction") {
                    Label("AI drafts commands progressively in a separate composer panel.", systemImage: "keyboard.badge.ellipsis")
                    Label("Execution stays blocked until you approve a command.", systemImage: "checkmark.shield")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AI Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                }
            }
            .onAppear {
                config = appStore.providerConfig
                apiKey = appStore.providerAPIKey() ?? ""
                if config.apiKeyReference == nil {
                    config.apiKeyReference = "provider.api.\(UUID().uuidString)"
                }
            }
        }
    }

    private func save() {
        errorMessage = nil
        do {
            try appStore.saveProviderConfig(config, apiKey: apiKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
