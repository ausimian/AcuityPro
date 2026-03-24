import SwiftUI

struct SphereTestView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel: SphereTestViewModel
    let onComplete: (FarPointMeasurement?) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Sphere Test — \(viewModel.eye.displayName) Eye",
                description: "You'll see a letter E on screen. Move the phone slowly closer and further away until you can clearly make out the prongs of the E, then tap to confirm.",
                systemImage: "scope",
                buttonLabel: "Start"
            ) {
                viewModel.startTracking(arService: arService)
            }

        case .active, .confirmation:
            activeTestView

        case .complete:
            Color.clear.onAppear {
                onComplete(viewModel.confirmedMeasurement)
            }
        }
    }

    private var activeTestView: some View {
        VStack(spacing: 0) {
            // Header: eye label + live readings
            header
                .padding(.top, 16)

            Spacer()

            // Target stimulus — tumbling E scaled to 20/40 angular size
            TumblingEView(size: viewModel.letterHeight, direction: viewModel.direction)
                .opacity(viewModel.letterHeight > 0 ? 1 : 0)
                .padding()

            Spacer()

            // Distance gauge
            DistanceGaugeView(
                distanceCm: viewModel.distanceCm,
                isStable: viewModel.isStable
            )
            .padding(.bottom, 20)

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    viewModel.confirmClear()
                } label: {
                    Text("I Can See the E Clearly")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.reportAlwaysClear()
                } label: {
                    Text("I can't find a blur point")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.eye.displayName) eye")
                    .font(.headline)
                Text("Sphere")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f D", viewModel.estimatedDioptres))
                    .font(.system(.title3, design: .rounded).bold())
                    .contentTransition(.numericText())
                Text("estimated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
}
