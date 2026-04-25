import SwiftUI

enum OpsAITheme {
    static let navy = Color(red: 0.01, green: 0.06, blue: 0.16)
    static let deepNavy = Color(red: 0.00, green: 0.03, blue: 0.10)
    static let card = Color(red: 0.03, green: 0.10, blue: 0.22)
    static let cardElevated = Color(red: 0.05, green: 0.15, blue: 0.30)
    static let cyan = Color(red: 0.08, green: 0.90, blue: 0.86)
    static let blue = Color(red: 0.05, green: 0.55, blue: 1.00)
    static let text = Color.white
    static let mutedText = Color.white.opacity(0.68)

    static let background = LinearGradient(
        colors: [deepNavy, navy, Color(red: 0.01, green: 0.09, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [blue, cyan],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension View {
    func opsCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(OpsAITheme.card.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}
