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
            Text("Which line looks darkest and sharpest?")
                .font(.headline)
                .multilineTextAlignment(.center)

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

            // Single primary-action slot: Confirm when a line is
            // selected, Ok (no astigmatism) when nothing is.
            Button {
                if let selected = selectedIndex {
                    onAxisSelected(axisDegrees(for: selected))
                } else {
                    onAxisSelected(0)
                }
            } label: {
                Text(selectedIndex == nil ? "Ok" : "Confirm")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
    }

    /// Converts a line index to TABO axis degrees (1–180, optometric convention).
    ///
    /// TABO: axis 0/180 is the horizontal meridian and axis 90 is the vertical
    /// meridian, measured CCW from the patient's right horizontal.
    ///
    /// `FanLine` renders a tall (vertical) rectangle and applies SwiftUI's
    /// `rotationEffect`, which rotates *clockwise* on screen. So index 0 with
    /// rotation 0° draws vertical (TABO axis 90), and rotation increases CW
    /// while TABO axis decreases — hence `90 − rotation` (mod 180).
    private func axisDegrees(for index: Int) -> Int {
        let stepDegrees = 180 / lineCount
        let rotation = index * stepDegrees                 // 0..165 for 12 lines
        let axis = ((90 - rotation) % 180 + 180) % 180     // 0..179
        return axis == 0 ? 180 : axis
    }
}

/// A single line in the fan chart with a wide invisible tap area.
///
/// All lines render *defocused* by default — fat-stroked and blurred,
/// so they read as equally out-of-focus bands. Tapping a line snaps it
/// into focus (thin, crisp, no blur) — the optometrist's "this axis
/// becomes visibly sharper than the others" cue.
private struct FanLine: View {
    let index: Int
    let lineCount: Int
    let isSelected: Bool

    var body: some View {
        let angle = Angle.degrees(Double(index) * (180.0 / Double(lineCount)))

        // Wide transparent hit area with a visible line centered in it.
        Rectangle()
            .fill(Color.clear)
            .frame(width: 30, height: 260)
            .overlay(
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: isSelected ? 3 : 5)
                    .blur(radius: isSelected ? 0 : 2.5)
            )
            .contentShape(Rectangle())
            .rotationEffect(angle)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
