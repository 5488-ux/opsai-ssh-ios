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
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(server.displayTitle)
                                            .font(.headline)
                                        Text("\(server.username)@\(server.host):\(server.port)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if !server.serverSize.isEmpty {
                                        Text(server.serverSize)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }

                                if !server.boundDomainList.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Label("绑定域名", systemImage: "globe")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)

                                        domainTagWrap(for: server)
                                    }
                                }

                                if !server.notes.isEmpty {
                                    Text(server.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
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

    @ViewBuilder
    private func domainTagWrap(for server: SSHServer) -> some View {
        let domains = Array(server.boundDomainList.prefix(3))

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(domains, id: \.self) { domain in
                    Text(domain)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            if server.boundDomainList.count > 3 {
                Text("还有 \(server.boundDomainList.count - 3) 个域名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
