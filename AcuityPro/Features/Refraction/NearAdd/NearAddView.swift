import SwiftUI

struct NearAddView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @StateObject var viewModel: NearAddViewModel
    let onComplete: (Float) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction, .active, .confirmation:
            VStack(spacing: 0) {
                Text("Near Add")
                    .font(.headline)
                    .padding(.top, 16)

                Spacer()

                Text("The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.")
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                GuidanceCircleView(
                    state: viewModel.guidanceState,
                    distanceCm: viewModel.distanceCm
                )
                .padding(.bottom, 20)

                VStack(spacing: 8) {
                    Text(String(format: "Near Add: +%.2f D", viewModel.computedNearAdd))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        viewModel.confirmDistance()
                    } label: {
                        Text("Ok")
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
            .onAppear {
                viewModel.startTracking(arService: arService)
            }
            .voiceInput(
                voiceCoordinator,
                prompt: "With both eyes open, hold your phone at your normal reading distance, then move the phone until the text is comfortable to read, and say okay.",
                vocabulary: ["okay", "ok"]
            ) { _ in viewModel.confirmDistance() }

        case .complete:
            Color.clear.onAppear {
                onComplete(viewModel.confirmedDistanceCm ?? viewModel.distanceCm)
            }
        }
    }
}
