import SwiftUI

struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appStore: AppStore

    @State private var server: SSHServer
    @State private var password = ""
    @State private var privateKey = ""
    @State private var errorMessage: String?

    init(server: SSHServer) {
        _server = State(initialValue: server)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器信息") {
                    TextField("显示名称", text: $server.name)
                    TextField("主机地址", text: $server.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("端口", value: $server.port, format: .number)
                        .keyboardType(.numberPad)
                    TextField("用户名", text: $server.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("服务器大小，例如：2C4G / 4C8G", text: $server.serverSize)
                    TextField("绑定域名，多个可用逗号或换行分隔", text: $server.boundDomains, axis: .vertical)
                        .lineLimit(2...5)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("认证方式") {
                    Picker("方式", selection: $server.authenticationMethod) {
                        ForEach(SSHServer.AuthenticationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    if server.authenticationMethod == .password {
                        SecureField("密码", text: $password)
                    } else {
                        Text("当前版本暂不支持私钥登录。请切换为密码登录后再保存。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("私钥内容", text: $privateKey, axis: .vertical)
                            .lineLimit(5...10)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("备注") {
                    TextField("可选备注", text: $server.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(server.name.isEmpty ? "新建服务器" : "编辑服务器")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                    }
                }
            }
            .onAppear {
                password = appStore.secret(for: server.passwordReference) ?? ""
                privateKey = appStore.secret(for: server.privateKeyReference) ?? ""
                if server.privateKeyReference == nil {
                    server.privateKeyReference = "server.key.\(server.id.uuidString)"
                }
                if server.passwordReference == nil {
                    server.passwordReference = "server.password.\(server.id.uuidString)"
                }
            }
        }
    }

    private func save() {
        errorMessage = nil

        guard !server.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "主机地址不能为空。"
            return
        }
        guard !server.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "用户名不能为空。"
            return
        }
        guard (1...65535).contains(server.port) else {
            errorMessage = "端口必须在 1 到 65535 之间。"
            return
        }
        guard server.authenticationMethod != .privateKey else {
            errorMessage = "当前版本暂不支持私钥登录，请改用密码登录。"
            return
        }
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "密码不能为空。"
            return
        }

        do {
            try appStore.upsertServer(
                server,
                password: server.authenticationMethod == .password ? password : nil,
                privateKey: server.authenticationMethod == .privateKey ? privateKey : nil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
