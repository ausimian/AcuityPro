import Combine
import SwiftUI

@MainActor
final class PDMeasurementViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var totalPdMm: Double = 0
    @Published var rightMonoPdMm: Double = 0
    @Published var leftMonoPdMm: Double = 0
    @Published var isStable: Bool = false
    @Published var distanceCm: Float = 0

    private let pdService = PupillaryDistanceService()
    private var cancellables = Set<AnyCancellable>()

    struct PDResult {
        let total: Double
        let right: Double
        let left: Double
    }

    private(set) var confirmedResult: PDResult?

    func startMeasuring(arService: ARFaceTrackingService) {
        pdService.startMeasuring(arService: arService)

        pdService.$totalPdMm.assign(to: &$totalPdMm)
        pdService.$rightMonoPdMm.assign(to: &$rightMonoPdMm)
        pdService.$leftMonoPdMm.assign(to: &$leftMonoPdMm)
        pdService.$isStable.assign(to: &$isStable)

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        step = .active
    }

    func stopMeasuring() {
        pdService.stopMeasuring()
    }

    func confirmPD() {
        confirmedResult = PDResult(
            total: totalPdMm,
            right: rightMonoPdMm,
            left: leftMonoPdMm
        )
        HapticFeedback.distanceLocked()
        step = .complete
    }
}
