import SwiftUI

struct SphereTestView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject var viewModel: SphereTestViewModel
    let onComplete: (FarPointMeasurement?) -> Void

    var body: some View {
        switch viewModel.step {
        case .instruction:
            PhaseInstructionView(
                title: "Sphere Test — \(viewModel.eye.displayName) Eye",
                description: "Start at arm's length (about 50 cm). A slightly fogged letter E will appear. Slowly bring the phone closer — stop and tap the moment the prongs become sharp. If the E is already clear at arm's length, let us know.",
                systemImage: "scope",
                buttonLabel: "Start"
            ) {
                viewModel.startTracking(arService: arService)
            }

        case .active, .confirmation:
            activeTestView

        case .complete:
            Color.clear.onAppear {
                onComplete(viewModel.confirmedMeasurement)
            }
        }
    }

    private var activeTestView: some View {
        VStack(spacing: 0) {
            // Header: eye label + live readings
            header
                .padding(.top, 16)

            Spacer()

            // Target stimulus — tumbling E scaled to 20/40 angular size.
            // Blur tapers from a small starting fog at 50 cm to zero as
            // the user moves the phone closer.
            TumblingEView(
                size: viewModel.letterHeight,
                direction: viewModel.direction,
                blurRadius: viewModel.blurRadius
            )
            .opacity(viewModel.letterHeight > 0 ? 1 : 0)
            .padding()

            Spacer()

            GuidanceCircleView(
                state: viewModel.guidanceState,
                distanceCm: viewModel.distanceCm
            )
            .padding(.bottom, 20)

            // Out-of-range hint when the phone has been pinned at the
            // ARKit ~25 cm floor for a couple of seconds.
            if viewModel.isAtFloor {
                outOfRangeHint
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    viewModel.confirmClear()
                } label: {
                    Text("I Found the Clear Point")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.reportAlwaysClear()
                } label: {
                    Text("The E is already clear")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                if viewModel.isAtFloor {
                    Button {
                        viewModel.reportOutOfRange()
                    } label: {
                        Text("Still blurry — out of range")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isAtFloor)
        }
    }

    private var outOfRangeHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("The phone can't measure closer than about 25 cm. If the E is still blurry, your prescription may be stronger than this screening can detect.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.eye.displayName) eye")
                    .font(.headline)
                Text("Sphere")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f D", viewModel.estimatedDioptres))
                    .font(.system(.title3, design: .rounded).bold())
                    .contentTransition(.numericText())
                Text("estimated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
}
