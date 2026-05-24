import SwiftUI

struct CalibrationView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @StateObject private var viewModel = CalibrationViewModel()
    let onCalibrated: () -> Void

    // Flips when "Got it…" actually starts speaking, so the headline
    // changes to "Locked!" in sync with the audio rather than the few
    // hundred ms earlier when isLocked first toggles.
    @State private var lockAnnounced = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Distance ring
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .foregroundStyle(.quaternary)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: viewModel.lockProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.lockProgress)

                VStack(spacing: 4) {
                    if viewModel.isTrackingFace {
                        Text("\(Int(viewModel.distanceCm))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("cm")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Looking for face...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Glasses reminder — accuracy depends on the user's
            // unaided refraction.
            HStack(spacing: 10) {
                Image(systemName: "eyeglasses")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Please remove your glasses or contact lenses before we begin.")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)

            // Instructions
            VStack(spacing: 8) {
                Text(instructionText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Target: \(Int(viewModel.distanceService.targetDistanceCm)) cm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            viewModel.startCalibration(arService: arService)
            voiceCoordinator.say(
                "Before we begin, please take off your glasses or contact lenses. " +
                "Then hold the phone at arm's length - about 50 centimetres away - and keep it steady.",
                // If the user is already at 50 cm, isLocked fires during
                // the intro and "Got it" gets queued behind it. The pause
                // keeps them from running together.
                postDelay: 0.6
            )
        }
        .onDisappear {
            viewModel.stopCalibration(arService: arService)
        }
        .onChange(of: viewModel.isLocked) { _, locked in
            if locked {
                HapticFeedback.distanceLocked()
                voiceCoordinator.say(
                    "Got it. Now we'll start your eye test.",
                    postDelay: 0.6,
                    onStart: { lockAnnounced = true },
                    onFinish: { onCalibrated() }
                )
            }
        }
    }

    private var ringColor: Color {
        if viewModel.isLocked { return .green }
        if viewModel.isInRange { return .green }
        return .orange
    }

    private var instructionText: String {
        if viewModel.isLocked && lockAnnounced {
            return "Locked! Starting test..."
        }
        if viewModel.isInRange {
            return "Hold steady..."
        }
        if !viewModel.isTrackingFace {
            return "Hold your phone at arm's length, screen facing you"
        }
        if viewModel.distanceCm < viewModel.distanceService.targetDistanceCm - viewModel.distanceService.toleranceCm {
            return "Move the phone further away"
        }
        return "Bring the phone a little closer"
    }
}
