import SwiftUI

/// A horizontal gauge showing the current phone-to-face distance
/// with directional hints for the user.
struct DistanceGaugeView: View {
    let distanceCm: Float
    let isStable: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: directionIcon)
                    .foregroundStyle(directionColor)

                Text("\(Int(distanceCm)) cm")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                if isStable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(directionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: isStable)
    }

    private var directionText: String {
        if isStable {
            return "Distance is steady"
        }
        return "Move the phone slowly to find focus"
    }

    private var directionIcon: String {
        if isStable { return "hand.raised.fill" }
        return "arrow.left.and.right"
    }

    private var directionColor: Color {
        isStable ? .green : .secondary
    }
}
