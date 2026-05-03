import SwiftUI

/// Second onboarding screen — collects the user's self-reported vision
/// symptom profile, then transitions into the refraction test.
struct SymptomQuestionView: View {
    @ObservedObject var arService: ARFaceTrackingService
    let age: Int
    @Binding var symptomProfile: VisionSymptomProfile?
    @State private var navigateToTest = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)

            VStack(spacing: 8) {
                Text("Which best describes your vision?")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text("Pick the option that fits best — this helps us interpret your results.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                ForEach(VisionSymptomProfile.allCases, id: \.self) { option in
                    symptomOptionButton(option)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button {
                navigateToTest = true
            } label: {
                Text("Begin Refraction Test")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(symptomProfile == nil)
            .padding(.bottom, 24)
        }
        .navigationDestination(isPresented: $navigateToTest) {
            RefractionCoordinatorView(
                arService: arService,
                age: age,
                symptomProfile: symptomProfile
            )
            .navigationBarBackButtonHidden()
        }
    }

    private func symptomOptionButton(_ option: VisionSymptomProfile) -> some View {
        let selected = symptomProfile == option
        return Button {
            symptomProfile = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(option.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(symptomOptionBackground(selected: selected))
        }
        .buttonStyle(.plain)
    }

    private func symptomOptionBackground(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(
                selected ? Color.accentColor : Color.secondary.opacity(0.3),
                lineWidth: selected ? 2 : 1
            )
    }
}
