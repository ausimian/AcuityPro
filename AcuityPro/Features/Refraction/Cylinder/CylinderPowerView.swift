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
                description: "You'll see a single line at \(viewModel.perpendicularAxis)\u{00B0}. Move the phone until this line becomes sharp and clear.",
                systemImage: "line.diagonal",
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f D", viewModel.estimatedDioptres))
                        .font(.system(.title3, design: .rounded).bold())
                        .contentTransition(.numericText())
                    Text("at \(viewModel.perpendicularAxis)\u{00B0}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Single line at the perpendicular axis
            Rectangle()
                .fill(Color.primary)
                .frame(width: 2, height: 200)
                .rotationEffect(.degrees(Double(viewModel.perpendicularAxis)))

            Spacer()

            DistanceGaugeView(
                distanceCm: viewModel.distanceCm,
                isStable: viewModel.isStable
            )
            .padding(.bottom, 20)

            Button {
                viewModel.confirmPowerClear()
            } label: {
                Text("Line is Clear")
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
}
