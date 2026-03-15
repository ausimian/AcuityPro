import AVFoundation
import ARKit
import Speech

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var microphoneAuthorized = false
    @Published var speechAuthorized = false
    @Published var deviceSupported = true
    @Published var hasCheckedPermissions = false

    var allPermissionsGranted: Bool {
        cameraAuthorized && microphoneAuthorized && speechAuthorized
    }

    var hasDeniedPermissions: Bool {
        hasCheckedPermissions && !allPermissionsGranted
    }

    func checkCapabilities() {
        deviceSupported = ARFaceTrackingConfiguration.isSupported
        checkCurrentStatus()
    }

    func requestAllPermissions() async {
        // Camera
        if !cameraAuthorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        }

        // Microphone
        if !microphoneAuthorized {
            let granted = await AVAudioApplication.requestRecordPermission()
            microphoneAuthorized = granted
        }

        // Speech recognition
        if !speechAuthorized {
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            speechAuthorized = (status == .authorized)
        }

        hasCheckedPermissions = true
    }

    private func checkCurrentStatus() {
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (cameraStatus == .authorized)

        // Microphone
        microphoneAuthorized = (AVAudioApplication.shared.recordPermission == .granted)

        // Speech
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        speechAuthorized = (speechStatus == .authorized)

        // If any have been explicitly denied/granted, we've checked
        let cameraDetermined = cameraStatus != .notDetermined
        let speechDetermined = speechStatus != .notDetermined
        hasCheckedPermissions = cameraDetermined && speechDetermined
    }
}
