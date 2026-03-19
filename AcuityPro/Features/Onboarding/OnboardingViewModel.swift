import AVFoundation
import ARKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var deviceSupported = true
    @Published var hasCheckedPermissions = false

    var allPermissionsGranted: Bool {
        cameraAuthorized
    }

    var hasDeniedPermissions: Bool {
        hasCheckedPermissions && !allPermissionsGranted
    }

    func checkCapabilities() {
        deviceSupported = ARFaceTrackingConfiguration.isSupported
        checkCurrentStatus()
    }

    func requestAllPermissions() async {
        if !cameraAuthorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        }

        hasCheckedPermissions = true
    }

    private func checkCurrentStatus() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (cameraStatus == .authorized)

        let cameraDetermined = cameraStatus != .notDetermined
        hasCheckedPermissions = cameraDetermined
    }
}
