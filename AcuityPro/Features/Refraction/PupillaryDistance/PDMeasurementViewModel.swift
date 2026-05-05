import Combine
import SwiftUI

@MainActor
final class PDMeasurementViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var totalPdMm: Double = 0
    @Published var rightMonoPdMm: Double = 0
    @Published var leftMonoPdMm: Double = 0
    @Published var isStable: Bool = false
    @Published var monoIsValid: Bool = false
    @Published var distanceCm: Float = 0

    private let pdService = PupillaryDistanceService()
    private var cancellables = Set<AnyCancellable>()

    /// Calibrated viewing distance for PD capture (cm).
    /// Distance must be within ±5 cm before Confirm is enabled.
    let targetDistanceCm: ClosedRange<Float> = 45...55

    struct PDResult {
        let total: Double
        let right: Double
        let left: Double
        let nearTotal: Double
        let nearRight: Double
        let nearLeft: Double
    }

    private(set) var confirmedResult: PDResult?

    /// True when the reading is trustworthy enough to commit:
    /// stable, head level, and within the calibrated viewing range.
    var canConfirm: Bool {
        isStable && monoIsValid && targetDistanceCm.contains(distanceCm)
    }

    func startMeasuring(arService: ARFaceTrackingService) {
        pdService.startMeasuring(arService: arService)

        pdService.$totalPdMm.assign(to: &$totalPdMm)
        pdService.$rightMonoPdMm.assign(to: &$rightMonoPdMm)
        pdService.$leftMonoPdMm.assign(to: &$leftMonoPdMm)
        pdService.$isStable.assign(to: &$isStable)
        pdService.$monoIsValid.assign(to: &$monoIsValid)

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        step = .active
    }

    func stopMeasuring() {
        pdService.stopMeasuring()
    }

    func confirmPD() {
        guard canConfirm else { return }
        // Near PD derivation — convergence rule of thumb: subtract ~3 mm
        // from distance PD when looking at near (~40 cm), with the shift
        // split evenly across the two mono values. A future PR can replace
        // this with a working-distance-dependent formula.
        confirmedResult = PDResult(
            total: totalPdMm,
            right: rightMonoPdMm,
            left: leftMonoPdMm,
            nearTotal: totalPdMm - 3,
            nearRight: rightMonoPdMm - 1.5,
            nearLeft: leftMonoPdMm - 1.5
        )
        HapticFeedback.distanceLocked()
        step = .complete
    }
}
