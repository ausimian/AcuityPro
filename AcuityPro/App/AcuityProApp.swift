import SwiftUI

@main
struct AcuityProApp: App {
    @StateObject private var arService = ARFaceTrackingService()
    @StateObject private var voiceCoordinator = VoiceCoordinator()

    var body: some Scene {
        WindowGroup {
            OnboardingView(arService: arService, voiceCoordinator: voiceCoordinator)
                .persistentSystemOverlays(.hidden) // Hide home indicator for better UX
        }
    }
}


