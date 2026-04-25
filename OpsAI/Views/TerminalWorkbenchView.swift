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
                manualCommandCard
                aiChatCard

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
                viewModel.isConnected ? "已连接" : "未连接",
                systemImage: viewModel.isConnected ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle"
            )
            .font(.headline)
            .foregroundStyle(viewModel.isConnected ? .green : .secondary)

            Text("\(viewModel.server.username)@\(viewModel.server.host):\(viewModel.server.port)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("重新连接") {
                    Task { await viewModel.connect() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBusy)

                Button("断开连接") {
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
            Text("终端输出")
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

    private var manualCommandCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手动命令")
                .font(.headline)

            Text("你可以直接输入命令并执行。这里不会经过 AI。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("例如：uname -a", text: $viewModel.manualCommand, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button("执行命令") {
                Task { await viewModel.runManualCommand() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.manualCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var aiChatCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 运维")
                .font(.headline)

            Text("像面板助手一样直接对话。AI 会先回答，再给出可批准执行的命令计划。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            quickPromptRow
            conversationList

            TextField("例如：排查 nginx 为什么返回 502", text: $viewModel.aiPrompt, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button(viewModel.isBusy ? "发送中..." : "发送问题") {
                Task { await viewModel.sendAIOpsMessage() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isBusy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var quickPromptRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        Task { await viewModel.useQuickPrompt(prompt) }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }

    private var conversationList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.conversation) { message in
                HStack {
                    if message.role == .assistant {
                        messageBubble(message, color: Color(.secondarySystemBackground), textColor: .primary)
                        Spacer(minLength: 28)
                    } else {
                        Spacer(minLength: 28)
                        messageBubble(message, color: Color.accentColor.opacity(0.14), textColor: .primary)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: AIOpsChatMessage, color: Color, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .assistant ? "AI 助手" : "你")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func aiPlanCard(_ plan: AIPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("命令计划")
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
