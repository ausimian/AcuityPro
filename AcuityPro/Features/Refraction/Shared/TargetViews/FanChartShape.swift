import SwiftUI

/// A fan chart stimulus — radial lines emanating from a centre point.
/// Used clinically to identify the axis of astigmatism: the line that
/// appears clearest/darkest corresponds to the cylinder axis.
struct FanChartView: View {
    let lineCount: Int
    let onAxisSelected: (Int) -> Void  // degrees 1-180

    @State private var selectedIndex: Int?

    init(lineCount: Int = 12, onAxisSelected: @escaping (Int) -> Void) {
        self.lineCount = lineCount
        self.onAxisSelected = onAxisSelected
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Which line appears clearest?")
                .font(.headline)

            ZStack {
                ForEach(0..<lineCount, id: \.self) { index in
                    FanLine(
                        index: index,
                        lineCount: lineCount,
                        isSelected: selectedIndex == index
                    )
                    .onTapGesture {
                        selectedIndex = index
                        HapticFeedback.letterTapped()
                    }
                }
            }
            .frame(width: 280, height: 280)

            if let selected = selectedIndex {
                let degrees = axisDegrees(for: selected)
                VStack(spacing: 8) {
                    Text("Axis: \(degrees)\u{00B0}")
                        .font(.system(.title3, design: .rounded).bold())

                    Button {
                        onAxisSelected(degrees)
                    } label: {
                        Text("Confirm Axis")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                }
            }

            Button {
                onAxisSelected(0) // 0 signals "no astigmatism"
            } label: {
                Text("All lines look the same")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }

    /// Converts a line index to axis degrees (1-180 range, optometry convention).
    private func axisDegrees(for index: Int) -> Int {
        let stepDegrees = 180 / lineCount
        let degrees = (index * stepDegrees) + stepDegrees  // 1-based, avoid 0
        return min(degrees, 180)
    }
}

/// A single line in the fan chart with a tappable hit area.
private struct FanLine: View {
    let index: Int
    let lineCount: Int
    let isSelected: Bool

    var body: some View {
        let angle = Angle.degrees(Double(index) * (180.0 / Double(lineCount)))

        Rectangle()
            .fill(isSelected ? Color.accentColor : Color.primary)
            .frame(width: isSelected ? 3 : 2, height: 260)
            .rotationEffect(angle)
            .contentShape(Rectangle().size(width: 30, height: 260))
    }
}
