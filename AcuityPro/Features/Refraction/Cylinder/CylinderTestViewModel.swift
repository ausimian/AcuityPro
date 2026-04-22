import Combine
import SwiftUI

@MainActor
final class CylinderTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var axisStep: PhaseStepState = .instruction
    @Published var powerStep: PhaseStepState = .instruction
    @Published var distanceCm: Float = 0
    @Published var estimatedDioptres: Double = 0
    @Published var isStable: Bool = false

    // MARK: - Properties

    let eye: Eye
    private(set) var selectedAxis: Int?
    private(set) var confirmedMeasurement: FarPointMeasurement?
    private let trackingService = FarPointTrackingService()

    init(eye: Eye) {
        self.eye = eye
    }

    // MARK: - Axis Phase

    func selectAxis(_ degrees: Int) {
        if degrees == 0 {
            // User reports no astigmatism
            selectedAxis = nil
            axisStep = .complete
        } else {
            selectedAxis = degrees
            HapticFeedback.distanceLocked()
            axisStep = .complete
        }
    }

    // MARK: - Power Phase

    func startPowerTracking(arService: ARFaceTrackingService) {
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

        powerStep = .active
    }

    func stopPowerTracking() {
        trackingService.stopTracking()
    }

    /// Confirm the perpendicular meridian far point.
    func confirmPowerClear() {
        guard let axis = selectedAxis else { return }
        let measurement = trackingService.confirmFarPoint(
            eye: eye,
            meridian: .cylinder(axisDegrees: axis)
        )
        confirmedMeasurement = measurement
        HapticFeedback.distanceLocked()
        powerStep = .complete
    }

    /// The perpendicular direction label (90 degrees from axis).
    var perpendicularAxis: Int {
        guard let axis = selectedAxis else { return 90 }
        let perp = (axis + 90) % 180
        return perp == 0 ? 180 : perp
    }
}
