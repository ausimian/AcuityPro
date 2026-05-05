import SwiftUI

struct PDMeasurementView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel = PDMeasurementViewModel()
    let onComplete: (_ result: PDMeasurementViewModel.PDResult) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Pupillary Distance",
                description: "Hold the phone at about 50 cm with your head level and look straight at the camera. We'll measure the distance between your pupils.",
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

                    statusLabel
                }

                Spacer()

                Text(String(format: "Distance: %d cm  (target ~50 cm)", Int(viewModel.distanceCm)))
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
                .disabled(!viewModel.canConfirm)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

        case .complete:
            Color.clear.onAppear {
                if let result = viewModel.confirmedResult {
                    onComplete(result)
                }
            }
        }
    }

    /// Single-line status hint that explains why Confirm is disabled
    /// (or confirms the reading is good).
    @ViewBuilder
    private var statusLabel: some View {
        if !viewModel.monoIsValid {
            Label("Look straight at the camera and keep your head level",
                  systemImage: "face.dashed")
                .foregroundStyle(.orange)
                .font(.subheadline)
        } else if !viewModel.viewingDistanceInRange {
            Label("Move to about 50 cm",
                  systemImage: "arrow.left.and.right")
                .foregroundStyle(.orange)
                .font(.subheadline)
        } else if !viewModel.isStable {
            Text("Hold still…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Label("Reading looks good", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
        }
    }
}

private extension PDMeasurementViewModel {
    var viewingDistanceInRange: Bool {
        targetDistanceCm.contains(distanceCm)
    }
}
