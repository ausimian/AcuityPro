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
    /// Distance must be within this range before Confirm is enabled.
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

    var viewingDistanceInRange: Bool {
        targetDistanceCm.contains(distanceCm)
    }

    /// True when the reading is trustworthy enough to commit:
    /// stable, head level, and within the calibrated viewing range.
    var canConfirm: Bool {
        isStable && monoIsValid && viewingDistanceInRange
    }

    func startMeasuring(arService: ARFaceTrackingService) {
        pdService.startMeasuring(arService: arService)

        pdService.$totalPdMm.assign(to: &$totalPdMm)
        pdService.$rightMonoPdMm.assign(to: &$rightMonoPdMm)
        pdService.$leftMonoPdMm.assign(to: &$leftMonoPdMm)
        pdService.$isStable.assign(to: &$isStable)

        arService.$faceIsLevel
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$monoIsValid)

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
        confirmedResult = PDResult(
            total: totalPdMm,
            right: rightMonoPdMm,
            left: leftMonoPdMm,
            nearTotal: totalPdMm - PupillaryDistanceService.nearPdTotalShiftMm,
            nearRight: rightMonoPdMm - PupillaryDistanceService.nearPdMonoShiftMm,
            nearLeft: leftMonoPdMm - PupillaryDistanceService.nearPdMonoShiftMm
        )
        HapticFeedback.distanceLocked()
        step = .complete
    }
}
