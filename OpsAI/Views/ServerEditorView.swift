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
                Section("Server") {
                    TextField("Display name", text: $server.name)
                    TextField("Host", text: $server.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", value: $server.port, format: .number)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $server.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Authentication") {
                    Picker("Method", selection: $server.authenticationMethod) {
                        ForEach(SSHServer.AuthenticationMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    if server.authenticationMethod == .password {
                        SecureField("Password", text: $password)
                    } else {
                        Text("Private key support is the next step. The real SSH connection in this build uses password login.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("Private key", text: $privateKey, axis: .vertical)
                            .lineLimit(5...10)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $server.notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(server.name.isEmpty ? "New Server" : "Edit Server")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
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
            errorMessage = "Host is required."
            return
        }
        guard !server.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Username is required."
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
