import SwiftUI

struct OnboardingView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var navigateToSymptom = false
    @State private var age: Int = 45
    @State private var symptomProfile: VisionSymptomProfile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                HStack(spacing: 16) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

                    Text("AcuityPro")
                        .font(.largeTitle.bold())
                }

                VStack(spacing: 4) {
                    Text("Check your vision in 60 seconds")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)

                    Text("Powered by iPhone technology")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                if !viewModel.deviceSupported {
                    unsupportedDeviceView
                } else if viewModel.hasDeniedPermissions {
                    permissionDeniedView
                } else {
                    agePickerView
                    continueButton
                }

                Spacer()

                Text("This is a screening tool only and does not replace a clinical eye examination.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .navigationDestination(isPresented: $navigateToSymptom) {
                SymptomQuestionView(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator,
                    age: age,
                    symptomProfile: $symptomProfile
                )
            }
        }
        .onAppear {
            viewModel.checkCapabilities()
        }
    }

    private var continueButton: some View {
        Button {
            Task {
                await viewModel.requestAllPermissions(voice: voiceCoordinator)
                if viewModel.allPermissionsGranted {
                    navigateToSymptom = true
                }
            }
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 40)
    }

    private var agePickerView: some View {
        VStack(spacing: 4) {
            Text("Your Age")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Age", selection: $age) {
                ForEach(18...80, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .padding(.horizontal, 40)
    }

    private var unsupportedDeviceView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("This device does not have a TrueDepth camera and cannot run this test.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            permissionRow("Camera", granted: viewModel.cameraAuthorized)

            Text("Camera permission is required. Please enable it in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 4)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func permissionRow(_ name: String, granted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(name)
                .font(.subheadline)
        }
    }
}
