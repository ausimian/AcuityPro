import SwiftUI

/// Reusable instruction overlay shown at the start of each refraction phase.
struct PhaseInstructionView: View {
    let title: String
    let description: String
    let systemImage: String
    let buttonLabel: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onContinue) {
                Text(buttonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
