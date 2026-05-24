import Combine
import SwiftUI
import UIKit

@MainActor
final class SphereTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var distanceCm: Float = 0
    @Published var estimatedDioptres: Double = 0
    @Published var isStable: Bool = false
    @Published var stabilityProgress: Double = 0
    @Published var step: PhaseStepState = .instruction
    @Published var letterHeight: CGFloat = 0
    @Published var blurRadius: CGFloat = 0
    /// True once the user has been pinned at the ~25 cm ARKit floor for
    /// `floorHoldDuration` seconds — they likely can't reach their far point
    /// inside the device's measurable range.
    @Published var isAtFloor: Bool = false
    private var hasReceivedFirstDistance = false
    private var floorHoldStartTime: Date?

    /// Distance-dependent fog: blur tapers from `maxBlurRadius` at the
    /// 50 cm calibration start to 0 at `blurEndDistanceCm`. Keeps a small
    /// amount of fog through most of the test range so accommodation stays
    /// relaxed, without a jarringly soft start.
    private static let maxBlurRadius: CGFloat = 0.8
    private static let blurStartDistanceCm: Float = 50
    private static let blurEndDistanceCm: Float = 18

    /// ARKit face tracking clamps near ~22–25 cm. Anyone whose far point is
    /// closer than this can't be measured by the device.
    private static let floorDistanceCm: Float = 27
    private static let floorHoldDuration: TimeInterval = 2.0

    /// How much closer the phone must have moved from the test's starting
    /// distance for `confirmClear()` to record a found far-point rather
    /// than "always clear at arm's length". Sits just above ARKit-smoothed
    /// hand drift (~1 cm) so a screening user with mild myopia in the
    /// −2.1 to −2.2 D range still registers — anything higher would
    /// silently fold real myopia into a plano reading.
    private static let movementThresholdCm: Float = 2.0
    private var startingDistanceCm: Float?

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
                self?.updateBlur(distanceCm: dist)
                self?.updateFloorHold(distanceCm: dist)
                self?.captureStartingDistance(dist)
            }
            .store(in: &cancellables)

        trackingService.$estimatedDioptres
            .receive(on: DispatchQueue.main)
            .assign(to: &$estimatedDioptres)

        trackingService.$isStable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isStable)

        trackingService.$stabilityProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$stabilityProgress)

        step = .active
    }

    /// State for `GuidanceCircleView`: pulse while the user gets started,
    /// fill the arc as the reading settles, snap to lock-in once stable.
    var guidanceState: GuidanceState {
        if isStable { return .lockIn }
        if stabilityProgress < 0.05 { return .idle }
        return .tracking(progress: stabilityProgress)
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

    private func updateBlur(distanceCm: Float) {
        let start = Self.blurStartDistanceCm
        let end = Self.blurEndDistanceCm
        let clamped = min(max(distanceCm, end), start)
        let t = CGFloat((clamped - end) / (start - end))   // 0 at end, 1 at start
        blurRadius = Self.maxBlurRadius * t
    }

    private func updateFloorHold(distanceCm: Float) {
        guard distanceCm > 0 else { return }
        if distanceCm <= Self.floorDistanceCm {
            if let start = floorHoldStartTime {
                if Date().timeIntervalSince(start) >= Self.floorHoldDuration {
                    isAtFloor = true
                }
            } else {
                floorHoldStartTime = Date()
            }
        } else {
            floorHoldStartTime = nil
            isAtFloor = false
        }
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

    /// User confirms the target is clear. If the phone hasn't moved
    /// meaningfully closer from the test's starting distance, the user
    /// likely never had to search — record this as plano. Otherwise the
    /// current distance gives us their far point.
    func confirmClear() {
        if let start = startingDistanceCm,
           (start - distanceCm) < Self.movementThresholdCm {
            reportAlwaysClear()
            return
        }
        let measurement = trackingService.confirmFarPoint(eye: eye, meridian: .sphere)
        confirmedMeasurement = measurement
        HapticFeedback.distanceLocked()
        step = .complete
    }

    private func captureStartingDistance(_ distanceCm: Float) {
        if startingDistanceCm == nil, distanceCm > 0 {
            startingDistanceCm = distanceCm
        }
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

    /// User reports they couldn't reach their far point — the phone hit the
    /// ARKit tracking floor while the E was still blurry. Records the floor
    /// distance with `outOfRange = true` so the result screen can flag it.
    func reportOutOfRange() {
        confirmedMeasurement = trackingService.confirmFarPoint(
            eye: eye,
            meridian: .sphere,
            outOfRange: true
        )
        HapticFeedback.distanceLocked()
        step = .complete
    }
}
