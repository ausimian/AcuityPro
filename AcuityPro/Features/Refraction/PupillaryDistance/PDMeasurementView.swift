import SwiftUI

struct PDMeasurementView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel = PDMeasurementViewModel()
    let onComplete: (_ total: Double, _ right: Double, _ left: Double) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Pupillary Distance",
                description: "Look straight at the camera and hold the phone at about 50cm. We'll measure the distance between your pupils.",
                systemImage: "ruler",
                buttonLabel: "Start"
            ) {
                viewModel.startMeasuring(arService: arService)
            }

        case .active, .confirmation:
            VStack(spacing: 0) {
                Text("Pupillary Distance")
                    .font(.headline)
                    .padding(.top, 16)

                Spacer()

                VStack(spacing: 16) {
                    Text(String(format: "%.1f mm", viewModel.totalPdMm))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    HStack(spacing: 32) {
                        VStack {
                            Text("R")
                                .font(.caption.bold())
                            Text(String(format: "%.1f", viewModel.rightMonoPdMm))
                                .font(.system(.title3, design: .rounded))
                        }
                        VStack {
                            Text("L")
                                .font(.caption.bold())
                            Text(String(format: "%.1f", viewModel.leftMonoPdMm))
                                .font(.system(.title3, design: .rounded))
                        }
                    }
                    .foregroundStyle(.secondary)

                    if viewModel.isStable {
                        Label("Reading stable", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    } else {
                        Text("Look straight at the camera and hold still...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(String(format: "Distance: %d cm", Int(viewModel.distanceCm)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)

                Button {
                    viewModel.confirmPD()
                } label: {
                    Text("Confirm PD")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

        case .complete:
            Color.clear.onAppear {
                if let result = viewModel.confirmedResult {
                    onComplete(result.total, result.right, result.left)
                }
            }
        }
    }
}
