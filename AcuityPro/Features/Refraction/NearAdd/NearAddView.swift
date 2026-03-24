import SwiftUI

struct NearAddView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel: NearAddViewModel
    let onComplete: (Float) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Near Reading Distance",
                description: "Hold the phone at your most comfortable reading distance — the distance where you'd normally read text on your phone.",
                systemImage: "book",
                buttonLabel: "Start"
            ) {
                viewModel.startTracking(arService: arService)
            }

        case .active, .confirmation:
            VStack(spacing: 0) {
                Text("Near Add")
                    .font(.headline)
                    .padding(.top, 16)

                Spacer()

                // Sample reading text
                VStack(spacing: 8) {
                    Text("The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Hold at your comfortable reading distance")
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
                    Text(String(format: "Near Add: +%.2f D", viewModel.computedNearAdd))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.confirmDistance()
                    } label: {
                        Text("This is Comfortable")
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
