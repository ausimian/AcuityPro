import SwiftUI

struct OnboardingView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var navigateToTest = false
    @State private var age: Int = 45

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

                Text("A sensor-driven refraction system using your iPhone's TrueDepth camera to measure your refractive error.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                if !viewModel.deviceSupported {
                    unsupportedDeviceView
                } else if viewModel.hasDeniedPermissions {
                    permissionDeniedView
                } else {
                    agePickerView
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
                RefractionCoordinatorView(arService: arService, age: age)
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
                await viewModel.requestAllPermissions()
                if viewModel.allPermissionsGranted {
                    navigateToTest = true
                }
            }
        } label: {
            Text("Begin Refraction Test")
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
            .frame(height: 100)
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
