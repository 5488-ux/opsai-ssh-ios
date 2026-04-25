import SwiftUI

struct TerminalWorkbenchView: View {
    @StateObject private var viewModel: TerminalSessionViewModel

    init(viewModel: TerminalSessionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                connectionCard
                terminalCard
                aiPromptCard

                if let plan = viewModel.aiPlan {
                    aiPlanCard(plan)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.server.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !viewModel.isConnected {
                await viewModel.connect()
            }
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                viewModel.isConnected ? "Connected" : "Disconnected",
                systemImage: viewModel.isConnected ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle"
            )
            .font(.headline)
            .foregroundStyle(viewModel.isConnected ? .green : .secondary)

            Text("\(viewModel.server.username)@\(viewModel.server.host):\(viewModel.server.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Reconnect") {
                    Task { await viewModel.connect() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)

                Button("Disconnect") {
                    Task { await viewModel.disconnect() }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isConnected || viewModel.isBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Terminal")
                .font(.headline)

            Text(viewModel.terminalOutput)
                .font(.system(.footnote, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.9))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var aiPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Ops")
                .font(.headline)

            Text("Describe the issue. OpsAI will draft commands in its own composer panel instead of auto-sending a chat message.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Example: check why nginx returns 502", text: $viewModel.aiPrompt, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button("Generate Command Plan") {
                Task { await viewModel.generatePlan() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func aiPlanCard(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Command Plan")
                .font(.headline)

            Text(plan.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(plan.commands) { draft in
                CommandDraftView(
                    draft: draft,
                    isDrafting: viewModel.draftingCommandIDs.contains(draft.id),
                    onChange: { newValue in
                        viewModel.updateCommand(draft.id, with: newValue)
                    },
                    onApprove: {
                        Task { await viewModel.approveAndRun(draft.id) }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
