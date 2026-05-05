import SwiftUI

/// Shows a single line perpendicular to the identified axis.
/// User moves phone until this line becomes clear to determine cylinder power.
struct CylinderPowerView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var viewModel: CylinderTestViewModel

    var body: some View {
        switch viewModel.powerStep {
        case .instruction:
            PhaseInstructionView(
                title: "Cylinder Power — \(viewModel.eye.displayName) Eye",
                description: "You'll see two sets of perpendicular lines. Move the phone until both sets look equally clear or equally blurred.",
                systemImage: "plus.square.dashed",
                buttonLabel: "Start"
            ) {
                viewModel.startPowerTracking(arService: arService)
            }

        case .active, .confirmation:
            activeView

        case .complete:
            EmptyView()
        }
    }

    private var activeView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.eye.displayName) Eye")
                        .font(.headline)
                    Text("Cylinder Power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.2f D", viewModel.estimatedDioptres))
                    .font(.system(.title3, design: .rounded).bold())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            fanAndBlockTarget

            Spacer()

            DistanceGaugeView(
                distanceCm: viewModel.distanceCm,
                isStable: viewModel.isStable
            )
            .padding(.bottom, 20)

            Button {
                viewModel.confirmPowerClear()
            } label: {
                Text("Both Sets Look Equal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    /// Fan-and-block target — two perpendicular blocks of parallel lines.
    /// The user confirms when both blocks look equally clear (or equally
    /// blurred); at that point the focal plane sits between the two
    /// principal meridians of astigmatism.
    ///
    /// Each `LineBlock` draws horizontal lines (TABO axis 180). To render
    /// lines at TABO axis `a` requires a SwiftUI rotation of `180 − a` —
    /// SwiftUI rotates clockwise on screen while TABO axis grows CCW from
    /// horizontal.
    private var fanAndBlockTarget: some View {
        let principalAxis = viewModel.selectedAxis ?? 90
        return ZStack {
            LineBlock()
                .rotationEffect(.degrees(Double(180 - principalAxis)))
            LineBlock()
                .rotationEffect(.degrees(Double(180 - viewModel.perpendicularAxis)))
        }
        .frame(width: 200, height: 200)
    }
}

/// A block of seven parallel horizontal lines (~120pt long).
/// Rotated by callers to represent a specific TABO axis.
private struct LineBlock: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 120, height: 1.5)
            }
        }
    }
}
