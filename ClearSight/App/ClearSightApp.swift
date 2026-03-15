import SwiftUI

@main
struct ClearSightApp: App {
    @StateObject private var arService = ARFaceTrackingService()

    var body: some Scene {
        WindowGroup {
            OnboardingView(arService: arService)
                .persistentSystemOverlays(.hidden) // Hide home indicator for better UX
        }
    }
}


