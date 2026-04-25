import SwiftUI

struct CommandDraftView: View {
    let draft: AIPlan.CommandDraft
    let isDrafting: Bool
    let onChange: (String) -> Void
    let onApprove: () -> Void
    let onAnalyzeOutput: (String) -> Void

    @State private var editableCommand: String

    init(
        draft: AIPlan.CommandDraft,
        isDrafting: Bool,
        onChange: @escaping (String) -> Void,
        onApprove: @escaping () -> Void,
        onAnalyzeOutput: @escaping (String) -> Void
    ) {
        self.draft = draft
        self.isDrafting = isDrafting
        self.onChange = onChange
        self.onApprove = onApprove
        self.onAnalyzeOutput = onAnalyzeOutput
        _editableCommand = State(initialValue: draft.command)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(draft.riskLevel.displayName, systemImage: riskIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(riskColor)

                Spacer()

                if draft.approvedAt != nil {
                    Label("已执行", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(OpsAITheme.cyan)
                } else if isDrafting {
                    Label("生成中", systemImage: "pencil.line")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(draft.reason)
                .font(.subheadline)
                .foregroundStyle(OpsAITheme.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text("命令")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OpsAITheme.mutedText)

                TextField("", text: $editableCommand, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(OpsAITheme.cardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(OpsAITheme.text)
                    .disabled(draft.approvedAt != nil)
                    .onChange(of: editableCommand) { _, newValue in
                        onChange(newValue)
                    }
                    .onChange(of: draft.command) { _, newValue in
                        editableCommand = newValue
                    }
            }

            Button(draft.approvedAt == nil ? "批准并执行" : "已执行") {
                onApprove()
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.approvedAt != nil || isDrafting)

            if let output = draft.output {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("执行结果")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OpsAITheme.mutedText)

                        Spacer()

                        Button("AI 分析") {
                            onAnalyzeOutput(output)
                        }
                        .buttonStyle(.bordered)
                        .font(.footnote)
                    }

                    Text(output)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(OpsAITheme.cyan)
                }
                .padding(12)
                .background(OpsAITheme.deepNavy.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .foregroundStyle(OpsAITheme.text)
        .padding(16)
        .background(OpsAITheme.cardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var riskIcon: String {
        switch draft.riskLevel {
        case .low:
            return "checkmark.shield"
        case .medium:
            return "exclamationmark.shield"
        case .high:
            return "flame"
        }
    }

    private var riskColor: Color {
        switch draft.riskLevel {
        case .low:
            return OpsAITheme.cyan
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
