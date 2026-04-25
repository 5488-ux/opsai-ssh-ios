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
                        "No Servers Yet",
                        systemImage: "server.rack",
                        description: Text("Add an SSH target and keep credentials locally on the device.")
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
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editorServer = server
                                isPresentingEditor = true
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
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
