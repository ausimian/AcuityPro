import AVFoundation
import ARKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var deviceSupported = true
    @Published var hasCheckedPermissions = false

    func checkCapabilities() {
        deviceSupported = ARFaceTrackingConfiguration.isSupported

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
            hasCheckedPermissions = true
        case .notDetermined:
            hasCheckedPermissions = false
        case .denied, .restricted:
            cameraAuthorized = false
            hasCheckedPermissions = true
        @unknown default:
            cameraAuthorized = false
            hasCheckedPermissions = true
        }
    }

    func requestCameraAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorized = granted
        hasCheckedPermissions = true
    }
}
