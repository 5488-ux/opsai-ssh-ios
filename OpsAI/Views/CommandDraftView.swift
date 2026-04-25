import SwiftUI

struct CommandDraftView: View {
    let draft: AIPlan.CommandDraft
    let isDrafting: Bool
    let onChange: (String) -> Void
    let onApprove: () -> Void

    @State private var editableCommand: String

    init(
        draft: AIPlan.CommandDraft,
        isDrafting: Bool,
        onChange: @escaping (String) -> Void,
        onApprove: @escaping () -> Void
    ) {
        self.draft = draft
        self.isDrafting = isDrafting
        self.onChange = onChange
        self.onApprove = onApprove
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
                    Label("Executed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isDrafting {
                    Label("Drafting", systemImage: "pencil.line")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text(draft.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Command")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("", text: $editableCommand, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(draft.approvedAt != nil)
                    .onChange(of: editableCommand) { _, newValue in
                        onChange(newValue)
                    }
            }

            Button(draft.approvedAt == nil ? "Approve and Run" : "Already Executed") {
                onApprove()
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.approvedAt != nil || isDrafting)

            if let output = draft.output {
                Text(output)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.separator), lineWidth: 1)
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
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
