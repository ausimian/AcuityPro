import SwiftUI

struct IntermediateAddView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel: IntermediateAddViewModel
    let onComplete: (Float) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Desktop Viewing Distance",
                description: "Hold the phone at the distance you'd normally view your desktop monitor or laptop screen.",
                systemImage: "desktopcomputer",
                buttonLabel: "Start"
            ) {
                viewModel.startTracking(arService: arService)
            }

        case .active, .confirmation:
            VStack(spacing: 0) {
                Text("Intermediate Add")
                    .font(.headline)
                    .padding(.top, 16)

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Hold at your typical screen distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                DistanceGaugeView(
                    distanceCm: viewModel.distanceCm,
                    isStable: viewModel.isStable
                )
                .padding(.bottom, 20)

                VStack(spacing: 8) {
                    Text(String(format: "Intermediate Add: +%.2f D", viewModel.computedIntermediateAdd))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.confirmDistance()
                    } label: {
                        Text("This is My Screen Distance")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

        case .complete:
            Color.clear.onAppear {
                onComplete(viewModel.confirmedDistanceCm ?? viewModel.distanceCm)
            }
        }
    }
}
