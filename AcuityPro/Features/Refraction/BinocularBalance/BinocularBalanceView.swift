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
            VStack(spacing: 28) {
                Spacer()

                progressIndicator

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
                        Text("Both are equal — finish test")
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

    /// Three-dot progress: filled for completed rounds, outlined ring for the
    /// current round, hollow for upcoming. Animates with each tap so the user
    /// has a clear visual confirmation of their answer landing.
    private var progressIndicator: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ForEach(0..<viewModel.totalIterations, id: \.self) { index in
                    progressDot(for: index)
                }
            }
            Text("Step \(min(viewModel.currentIteration + 1, viewModel.totalIterations)) of \(viewModel.totalIterations)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.currentIteration)
    }

    @ViewBuilder
    private func progressDot(for index: Int) -> some View {
        let completed = index < viewModel.currentIteration
        let current = index == viewModel.currentIteration

        Circle()
            .fill(completed ? Color.accentColor : Color.clear)
            .overlay(
                Circle()
                    .stroke(current ? Color.accentColor : Color.secondary.opacity(0.4),
                            lineWidth: current ? 2 : 1)
            )
            .frame(width: current ? 16 : 12, height: current ? 16 : 12)
    }
}
