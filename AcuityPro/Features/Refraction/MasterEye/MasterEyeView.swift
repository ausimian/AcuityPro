import SwiftUI

struct MasterEyeView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel = MasterEyeViewModel()
    let onComplete: (Eye) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Dominant Eye Test",
                description: "Look at the target with both eyes open. You'll be asked to close each eye one at a time and report how much the image shifts.",
                systemImage: "eye",
                buttonLabel: "Start"
            ) {
                viewModel.startTest(arService: arService)
            }

        case .active, .confirmation:
            VStack(spacing: 32) {
                Spacer()

                // Target to focus on
                Circle()
                    .fill(Color.primary)
                    .frame(width: 20, height: 20)

                Text(instructionText)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        let closedEye: Eye = viewModel.testPhase == .closingRight ? .right : .left
                        viewModel.recordClarity(closedEye: closedEye, noticeable: true)
                    } label: {
                        Text("Big shift — very noticeable")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        let closedEye: Eye = viewModel.testPhase == .closingRight ? .right : .left
                        viewModel.recordClarity(closedEye: closedEye, noticeable: false)
                    } label: {
                        Text("Little or no shift")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

        case .complete:
            Color.clear.onAppear {
                if let dominant = viewModel.dominantEye {
                    onComplete(dominant)
                }
            }
        }
    }

    private var instructionText: String {
        switch viewModel.testPhase {
        case .closingRight:
            return "Close your RIGHT eye.\nHow much did the image shift?"
        case .closingLeft:
            return "Now close your LEFT eye.\nHow much did the image shift?"
        case .result:
            return ""
        }
    }
}
