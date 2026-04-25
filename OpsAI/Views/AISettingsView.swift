import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var config: AIProviderConfig
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @State private var testMessage: String?
    @State private var isTestingAPI = false

    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol = AIService()) {
        self.aiService = aiService
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
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("行为设置") {
                    Toggle("每条命令都必须人工批准", isOn: $config.requireApprovalPerCommand)
                    TextField("系统提示词", text: $config.systemPrompt, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("API 测试") {
                    Button(isTestingAPI ? "测试中..." : "测试 API") {
                        Task { await testAPI() }
                    }
                    .disabled(isTestingAPI)

                    if let testMessage {
                        Text(testMessage)
                            .foregroundStyle(testMessage.contains("成功") ? .green : .orange)
                    }
                }

                Section("交互说明") {
                    Label("这里填写的接口密钥会保存在本机钥匙串中，并作为真实请求的 Bearer Token。", systemImage: "key")
                    Label("在你批准之前，命令不会自动执行。", systemImage: "checkmark.shield")
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
                    config.apiKeyReference = AIProviderConfig.defaultAPIKeyReference
                }
            }
        }
    }

    private func save() {
        errorMessage = nil
        testMessage = nil

        guard validateInputs() else { return }

        do {
            try appStore.saveProviderConfig(config, apiKey: apiKey)
            testMessage = "配置已保存。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validateInputs() -> Bool {
        guard !config.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "提供方名称不能为空。"
            return false
        }

        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "接口地址不能为空。"
            return false
        }

        guard !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "模型不能为空。"
            return false
        }

        return true
    }

    private func testAPI() async {
        errorMessage = nil
        testMessage = nil

        guard validateInputs() else { return }

        isTestingAPI = true
        defer { isTestingAPI = false }

        do {
            let message = try await aiService.testConnection(config: config, apiKey: apiKey)
            testMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
