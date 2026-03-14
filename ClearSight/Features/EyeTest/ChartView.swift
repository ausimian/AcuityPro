import SwiftUI

/// Renders a single row of Snellen chart letters at the correct scaled size.
struct ChartView: View {
    let letters: [Character]
    let letterHeight: CGFloat
    let userResponseCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: letterSpacing) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    Text(String(letter))
                        .font(.system(size: letterHeight, weight: .medium, design: .monospaced))
                        .foregroundStyle(letterColor(at: index))
                }
            }
        }
        .accessibilityHidden(true) // Don't announce chart letters via VoiceOver
    }

    private var letterSpacing: CGFloat {
        max(letterHeight * 0.3, 4)
    }

    private func letterColor(at index: Int) -> Color {
        if index < userResponseCount {
            return .secondary.opacity(0.3) // Already answered
        }
        return .primary
    }
}
