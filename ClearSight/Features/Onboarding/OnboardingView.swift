import SwiftUI

struct OnboardingView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var navigateToTest = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                Text("ClearSight")
                    .font(.largeTitle.bold())

                Text("A quick visual acuity screening using your iPhone's TrueDepth camera.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                if !viewModel.deviceSupported {
                    unsupportedDeviceView
                } else if viewModel.hasCheckedPermissions && !viewModel.cameraAuthorized {
                    cameraPermissionDeniedView
                } else {
                    startButton
                }

                Spacer()

                Text("This is a screening tool only and does not replace a clinical eye examination.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .navigationDestination(isPresented: $navigateToTest) {
                EyeTestView(arService: arService)
                    .navigationBarBackButtonHidden()
            }
        }
        .onAppear {
            viewModel.checkCapabilities()
        }
    }

    private var startButton: some View {
        Button {
            Task {
                if !viewModel.hasCheckedPermissions {
                    await viewModel.requestCameraAccess()
                }
                if viewModel.cameraAuthorized {
                    navigateToTest = true
                }
            }
        } label: {
            Text("Begin Eye Test")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.title)
                .foregroundStyle(.red)
            Text("Camera access is required. Please enable it in Settings.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}
