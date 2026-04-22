import Combine
import SwiftUI
import UIKit

@MainActor
final class SphereTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var distanceCm: Float = 0
    @Published var estimatedDioptres: Double = 0
    @Published var isStable: Bool = false
    @Published var step: PhaseStepState = .instruction
    @Published var letterHeight: CGFloat = 0
    private var hasReceivedFirstDistance = false

    // MARK: - Properties

    let eye: Eye
    let direction: TumblingEDirection = .random
    private let trackingService = FarPointTrackingService()
    private(set) var confirmedMeasurement: FarPointMeasurement?

    /// 20/40 letter subtends 10 arcminutes — large enough to be practical at 50cm
    /// while still providing a clear blur/sharp transition for far-point detection.
    private static let targetArcminRadians: Double = 10.0 / 60.0 * .pi / 180.0

    init(eye: Eye) {
        self.eye = eye
    }

    // MARK: - Flow

    func startTracking(arService: ARFaceTrackingService) {
        trackingService.startTracking(arService: arService)

        trackingService.$currentDistanceCm
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dist in
                self?.distanceCm = dist
                self?.updateLetterHeight(distanceCm: dist)
            }
            .store(in: &cancellables)

        trackingService.$estimatedDioptres
            .receive(on: DispatchQueue.main)
            .assign(to: &$estimatedDioptres)

        trackingService.$isStable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isStable)

        step = .active
    }

    private var cancellables = Set<AnyCancellable>()

    /// Compute the on-screen letter height so the E subtends 10 arcmin
    /// (20/40 angular size) at the current viewing distance.
    private func updateLetterHeight(distanceCm: Float) {
        let distanceMM = Double(distanceCm) * 10.0
        guard distanceMM > 0 else { return }
        let heightMM = distanceMM * tan(Self.targetArcminRadians)
        let points = CGFloat(heightMM) * Self.pointsPerMM
        if !hasReceivedFirstDistance {
            hasReceivedFirstDistance = true
            // Set immediately without animation on first reading
            letterHeight = max(points, 4)
            return
        }
        letterHeight = max(points, 4)  // floor at 4pt to remain visible
    }

    // MARK: - Device Display

    private static var pointsPerMM: CGFloat {
        let scale = UIScreen.main.scale
        let ppi: CGFloat = scale >= 3.0 ? 460 : 326
        return (ppi / scale) / 25.4
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
