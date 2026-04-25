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

                if let snapshot = viewModel.serverConfigSnapshot {
                    serverConfigCard(snapshot)
                }

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

            if !viewModel.boundDomains.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("绑定域名", systemImage: "globe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    domainTagWrap(domains: viewModel.boundDomains)
                }
            }

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

                Button("扫描绑定域名") {
                    Task { await viewModel.scanBoundDomains() }
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isConnected || viewModel.isBusy)

                Button("扫描服务器配置") {
                    Task { await viewModel.scanServerConfiguration() }
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
            HStack {
                Text("终端输出")
                    .font(.headline)

                Spacer()

                Button("交给 AI 分析") {
                    Task { await viewModel.analyzeTerminalOutput() }
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                .disabled(viewModel.isBusy)
            }

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

            Text("像宝塔面板的 AI 助手一样直接对话。先选助手，再提问；如果需要执行命令，仍然要你逐条批准。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            assistantPickerRow
            quickPromptRow
            diagnosticToolSection
            conversationList

            TextField(viewModel.selectedAssistant.promptPlaceholder, text: $viewModel.aiPrompt, axis: .vertical)
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

    private var assistantPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIAssistantProfile.allCases) { assistant in
                    Button {
                        viewModel.selectAssistant(assistant)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(assistant.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(assistant.shortDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                        .padding(12)
                        .background(
                            viewModel.selectedAssistant == assistant
                                ? Color.accentColor.opacity(0.16)
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isBusy)
                }
            }
        }
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

    private var diagnosticToolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("技能工具")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("只读")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.14))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            ForEach(viewModel.diagnosticTools, id: \.id) { tool in
                VStack(alignment: .leading, spacing: 10) {
                    Text(tool.displayName)
                        .font(.subheadline.weight(.semibold))

                    Text(tool.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("运行工具") {
                            Task { await viewModel.runDiagnosticTool(tool, analyzeAfterRun: false) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isBusy)

                        Button("运行并分析") {
                            Task { await viewModel.runDiagnosticTool(tool, analyzeAfterRun: true) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isBusy)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
            Text(message.role == .assistant ? viewModel.selectedAssistant.displayName : "你")
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
                    },
                    onAnalyzeOutput: { output in
                        Task {
                            await viewModel.analyzeExecutionOutput(
                                output,
                                sourceLabel: "命令 \(draft.command)"
                            )
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func serverConfigCard(_ snapshot: ServerConfigSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("服务器配置概览")
                    .font(.headline)

                Spacer()

                Button("AI 分析") {
                    Task { await viewModel.analyzeServerConfiguration() }
                }
                .buttonStyle(.borderedProminent)
                .font(.footnote)
                .disabled(viewModel.isBusy)
            }

            Text("扫描时间：\(snapshot.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)

            configRow(title: "主机", value: snapshot.hostName)
            configRow(title: "系统", value: snapshot.operatingSystem)
            configRow(title: "运行时间", value: snapshot.uptimeSummary)
            configRow(title: "内存", value: snapshot.memorySummary)
            configRow(title: "根分区", value: snapshot.rootDiskSummary)

            if !snapshot.listeningPorts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("监听端口")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    domainTagWrap(domains: snapshot.listeningPorts)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("服务状态")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(snapshot.services) { service in
                    HStack(alignment: .top) {
                        Text(service.name)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 72, alignment: .leading)

                        Text(service.state.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(for: service.state).opacity(0.14))
                            .foregroundStyle(statusColor(for: service.state))
                            .clipShape(Capsule())

                        Text(service.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func configRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private func domainTagWrap(domains: [String]) -> some View {
        let visibleDomains = Array(domains.prefix(4))

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(visibleDomains, id: \.self) { domain in
                    Text(domain)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            if domains.count > 4 {
                Text("还有 \(domains.count - 4) 个域名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusColor(for state: ServerConfigSnapshot.ServiceStatus.State) -> Color {
        switch state {
        case .running:
            return .green
        case .stopped:
            return .red
        case .unknown:
            return .orange
        }
    }
}
