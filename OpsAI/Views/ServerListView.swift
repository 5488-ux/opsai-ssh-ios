import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var appStore: AppStore
    @State private var editorServer = SSHServer(
        passwordReference: "server.password.\(UUID().uuidString)"
    )
    @State private var terminalServer: SSHServer?
    @State private var isPresentingEditor = false

    var body: some View {
        NavigationStack {
            List {
                if appStore.servers.isEmpty {
                    ContentUnavailableView(
                        "还没有服务器",
                        systemImage: "server.rack",
                        description: Text("添加一个 SSH 目标后，凭证会仅保存在本机设备中。")
                    )
                } else {
                    ForEach(appStore.servers) { server in
                        Button {
                            terminalServer = server
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(server.displayTitle)
                                    .font(.headline)
                                Text("\(server.username)@\(server.host):\(server.port)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if !server.notes.isEmpty {
                                    Text(server.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                appStore.deleteServer(server)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                editorServer = server
                                isPresentingEditor = true
                            } label: {
                                Label("编辑", systemImage: "square.and.pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle("OpsAI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorServer = SSHServer(
                            passwordReference: "server.password.\(UUID().uuidString)",
                            privateKeyReference: "server.key.\(UUID().uuidString)"
                        )
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                ServerEditorView(server: editorServer)
            }
            .navigationDestination(item: $terminalServer) { server in
                TerminalWorkbenchView(viewModel: TerminalSessionViewModel(server: server, appStore: appStore))
            }
        }
    }
}
