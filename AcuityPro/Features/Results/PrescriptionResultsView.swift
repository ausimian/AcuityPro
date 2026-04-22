import SwiftUI

struct PrescriptionResultsView: View {
    @StateObject var viewModel: PrescriptionResultsViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Your Refraction Results")
                .font(.title2.bold())

            if let rx = viewModel.prescription {
                prescriptionTable(rx)

                pdSection(rx)

                Text("Dominant Eye: \(rx.dominantEye.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                ShareLink(item: viewModel.shareSummary) {
                    Label("Share Results", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.testAgain()
                } label: {
                    Text("Test Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Text("This is a screening tool only and does not replace a clinical eye examination.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
    }

    private func prescriptionTable(_ rx: FullPrescription) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("").frame(width: 30)
                Text("SPH").frame(maxWidth: .infinity)
                Text("CYL").frame(maxWidth: .infinity)
                Text("AXIS").frame(maxWidth: .infinity)
                Text("ADD").frame(maxWidth: .infinity)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)

            Divider()

            // Right eye
            eyeRow("R", prescription: rx.rightEye)
                .padding(.vertical, 8)

            Divider()

            // Left eye
            eyeRow("L", prescription: rx.leftEye)
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private func eyeRow(_ label: String, prescription: EyePrescription) -> some View {
        HStack {
            Text(label)
                .font(.headline)
                .frame(width: 30)

            Text(formatDioptre(prescription.sphere))
                .frame(maxWidth: .infinity)

            Text(prescription.cylinder == 0 ? "DS" : formatDioptre(prescription.cylinder))
                .frame(maxWidth: .infinity)

            Text(prescription.cylinder == 0 ? "-" : "\(prescription.axis)\u{00B0}")
                .frame(maxWidth: .infinity)

            Text(prescription.nearAdd.map { formatDioptre($0) } ?? "-")
                .frame(maxWidth: .infinity)
        }
        .font(.system(.body, design: .monospaced))
    }

    private func pdSection(_ rx: FullPrescription) -> some View {
        HStack(spacing: 16) {
            Label(String(format: "PD: %.1f mm", rx.pdMm), systemImage: "ruler")
            Text(String(format: "(R: %.1f / L: %.1f)", rx.monoPdRightMm, rx.monoPdLeftMm))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private func formatDioptre(_ value: Double) -> String {
        String(format: "%+.2f", value)
    }
}
