import AVFoundation
import ARKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var deviceSupported = true
    @Published var hasCheckedPermissions = false

    /// Camera is the only required permission — voice (mic + speech
    /// recognition) is desired but optional, so the test still works
    /// via taps if the user declines.
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

    func requestAllPermissions(voice: VoiceCoordinator) async {
        if !cameraAuthorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        }

        // Voice permissions are optional — fire and forget. The
        // coordinator's own `isAuthorized` flag gates voice features;
        // declining here just leaves the test button-driven.
        await voice.requestAuthorization()

        hasCheckedPermissions = true
    }

    private func checkCurrentStatus() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (cameraStatus == .authorized)

        let cameraDetermined = cameraStatus != .notDetermined
        hasCheckedPermissions = cameraDetermined
    }
}
