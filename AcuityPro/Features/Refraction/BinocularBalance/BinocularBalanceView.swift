import SwiftUI

struct BinocularBalanceView: View {
    @StateObject var viewModel = BinocularBalanceViewModel()
    let onComplete: (_ rightAdj: Double, _ leftAdj: Double) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Binocular Balance",
                description: "With both eyes open, compare the clarity of vision between your right and left eyes. This helps fine-tune your prescription.",
                systemImage: "eyes",
                buttonLabel: "Start"
            ) {
                viewModel.startTest()
            }

        case .active, .confirmation:
            VStack(spacing: 32) {
                Spacer()

                Text("Round \(viewModel.currentIteration + 1) of 3")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Two comparison targets
                HStack(spacing: 40) {
                    VStack {
                        Text("E")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                        Text("Right")
                            .font(.caption)
                    }
                    VStack {
                        Text("E")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                        Text("Left")
                            .font(.caption)
                    }
                }

                Text("Which eye sees more clearly?")
                    .font(.title3)

                VStack(spacing: 12) {
                    Button {
                        viewModel.reportClearer(eye: .right)
                    } label: {
                        Text("Right eye is clearer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        viewModel.reportClearer(eye: .left)
                    } label: {
                        Text("Left eye is clearer")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        viewModel.reportClearer(eye: nil)
                    } label: {
                        Text("Both are the same")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

        case .complete:
            Color.clear.onAppear {
                onComplete(viewModel.rightAdjustment, viewModel.leftAdjustment)
            }
        }
    }
}
