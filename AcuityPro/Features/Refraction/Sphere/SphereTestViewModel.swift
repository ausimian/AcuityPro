import Combine
import SwiftUI

@MainActor
final class SphereTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var distanceCm: Float = 0
    @Published var estimatedDioptres: Double = 0
    @Published var isStable: Bool = false
    @Published var step: PhaseStepState = .instruction

    // MARK: - Properties

    let eye: Eye
    private let trackingService = FarPointTrackingService()
    private(set) var confirmedMeasurement: FarPointMeasurement?

    init(eye: Eye) {
        self.eye = eye
    }

    // MARK: - Flow

    func startTracking(arService: ARFaceTrackingService) {
        trackingService.startTracking(arService: arService)

        trackingService.$currentDistanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        trackingService.$estimatedDioptres
            .receive(on: DispatchQueue.main)
            .assign(to: &$estimatedDioptres)

        trackingService.$isStable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isStable)

        step = .active
    }

    func stopTracking() {
        trackingService.stopTracking()
    }

    /// User confirms the target is clear at the current distance.
    func confirmClear() {
        let measurement = trackingService.confirmFarPoint(eye: eye, meridian: .sphere)
        confirmedMeasurement = measurement
        HapticFeedback.distanceLocked()
        step = .complete
    }

    /// User reports the target is always clear (emmetropia/hyperopia).
    func reportAlwaysClear() {
        // Record plano (0 dioptres) — no refractive error detectable
        confirmedMeasurement = FarPointMeasurement(
            distanceCm: 0,
            eye: eye,
            meridian: .sphere
        )
        step = .complete
    }
}
