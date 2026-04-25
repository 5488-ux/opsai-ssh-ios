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
                Section("服务提供方") {
                    TextField("提供方名称", text: $config.providerName)
                    TextField("接口地址", text: $config.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("模型", text: $config.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("接口密钥", text: $apiKey)
                }

                Section("行为设置") {
                    Toggle("每条命令都必须人工批准", isOn: $config.requireApprovalPerCommand)
                    TextField("系统提示词", text: $config.systemPrompt, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("交互说明") {
                    Label("AI 会在独立的命令草稿区逐步生成命令。", systemImage: "keyboard.badge.ellipsis")
                    Label("在你批准之前，命令不会执行。", systemImage: "checkmark.shield")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AI 设置")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
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
