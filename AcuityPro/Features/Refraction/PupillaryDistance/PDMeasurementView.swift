import SwiftUI

struct PDMeasurementView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @StateObject var viewModel = PDMeasurementViewModel()
    let onComplete: (_ result: PDMeasurementViewModel.PDResult) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction, .active, .confirmation:
            VStack(spacing: 0) {
                gazeTargetDot
                    .padding(.top, 8)

                Text("Pupillary Distance")
                    .font(.headline)
                    .padding(.top, 8)

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

                GuidanceCircleView(
                    state: viewModel.guidanceState,
                    distanceCm: viewModel.distanceCm
                )
                .padding(.bottom, 60)
            }
            .onAppear {
                voiceCoordinator.say(
                    "Now, I'll measure your pupillary distance. Hold the phone at arm's length, about 50 centimetres, and look at the dot at the top of the screen.",
                    onFinish: {
                        viewModel.startMeasuring(arService: arService)
                    }
                )
            }
            .onDisappear {
                voiceCoordinator.stopListening()
            }

        case .complete:
            Color.clear.onAppear {
                if let result = viewModel.confirmedResult {
                    voiceCoordinator.say("Done", onFinish: {
                        onComplete(result)
                    })
                }
            }
        }
    }

    /// Small dot positioned near the device's front camera. The user is
    /// asked to look at it; the AR service reports whether their gaze is
    /// within tolerance of the camera direction. Green = on-target.
    private var gazeTargetDot: some View {
        Circle()
            .fill(viewModel.isLookingAtCamera ? Color.green : Color.gray.opacity(0.6))
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(viewModel.isLookingAtCamera ? Color.green : Color.white.opacity(0.7), lineWidth: 2)
                    .scaleEffect(viewModel.isLookingAtCamera ? 1.6 : 1.0)
                    .opacity(viewModel.isLookingAtCamera ? 0 : 1)
                    .animation(.easeOut(duration: 0.6).repeatForever(autoreverses: false),
                               value: viewModel.isLookingAtCamera)
            )
    }

    /// Single-line status hint that explains why Confirm is disabled
    /// (or confirms the reading is good).
    @ViewBuilder
    private var statusLabel: some View {
        if !viewModel.isLookingAtCamera {
            Label("Look at the dot at the top of the screen",
                  systemImage: "eye")
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

