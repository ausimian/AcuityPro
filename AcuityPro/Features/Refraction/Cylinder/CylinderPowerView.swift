import SwiftUI

/// Shows a single line perpendicular to the identified axis.
/// User moves phone until this line becomes clear to determine cylinder power.
struct CylinderPowerView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @ObservedObject var viewModel: CylinderTestViewModel

    var body: some View {
        switch viewModel.powerStep {
        case .instruction:
            if voiceCoordinator.isAuthorized {
                // Voice mode: skip the static instruction screen and
                // speak the cue while the active test view is on screen.
                Color.clear.onAppear {
                    viewModel.startPowerTracking(arService: arService)
                    voiceCoordinator.say(
                        "Move the phone slowly until both sets of lines look equally clear, or equally blurred. Then say okay."
                    )
                }
            } else {
                PhaseInstructionView(
                    title: "Cylinder Power — \(viewModel.eye.displayName) Eye",
                    description: "You'll see two sets of perpendicular lines. Move the phone until both sets look equally clear or equally blurred.",
                    systemImage: "plus.square.dashed",
                    buttonLabel: "Start"
                ) {
                    viewModel.startPowerTracking(arService: arService)
                }
            }

        case .active, .confirmation:
            activeView

        case .complete:
            EmptyView()
        }
    }

    private var activeView: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.eye.displayName) Eye")
                        .font(.headline)
                    Text("Cylinder Power")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.2f D", viewModel.estimatedDioptres))
                    .font(.system(.title3, design: .rounded).bold())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            fanAndBlockTarget

            Spacer()

            GuidanceCircleView(
                state: viewModel.guidanceState,
                distanceCm: viewModel.distanceCm
            )
            .padding(.bottom, 20)

            Button {
                viewModel.confirmPowerClear()
            } label: {
                Text("Ok")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .voiceInput(
            voiceCoordinator,
            vocabulary: ["okay", "ok"]
        ) { _ in viewModel.confirmPowerClear() }
    }

    /// `LineBlock` draws horizontal lines (TABO axis 180); rendering at
    /// TABO axis `a` requires a SwiftUI rotation of `180 − a` (CW on
    /// screen vs TABO's CCW-from-horizontal convention).
    private var fanAndBlockTarget: some View {
        let principalAxis = viewModel.selectedAxis ?? 90
        return ZStack {
            LineBlock()
                .rotationEffect(.degrees(Double(180 - principalAxis)))
            LineBlock()
                .rotationEffect(.degrees(Double(180 - viewModel.perpendicularAxis)))
        }
        .frame(width: 200, height: 200)
    }
}

private struct LineBlock: View {
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { _ in
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 120, height: 1.5)
            }
        }
    }
}
