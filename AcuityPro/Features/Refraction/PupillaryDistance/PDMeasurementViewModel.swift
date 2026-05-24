import Combine
import SwiftUI

@MainActor
final class PDMeasurementViewModel: ObservableObject {

    @Published var step: PhaseStepState = .active
    @Published var totalPdMm: Double = 0
    @Published var rightMonoPdMm: Double = 0
    @Published var leftMonoPdMm: Double = 0
    @Published var isStable: Bool = false
    @Published var isLookingAtCamera: Bool = false
    @Published var distanceCm: Float = 0
    @Published var stabilityProgress: Double = 0

    private let pdService = PupillaryDistanceService()
    private var cancellables = Set<AnyCancellable>()
    private var didStartMeasuring = false
    private var holdStart: Date?
    private var holdTimer: Timer?
    private let requiredHoldSeconds: TimeInterval = 3.0

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
    /// stable, the user is looking at the on-screen target dot, and
    /// the phone is at the calibrated viewing distance.
    var canConfirm: Bool {
        isStable && isLookingAtCamera && viewingDistanceInRange
    }

    var guidanceState: GuidanceState {
        if step == .complete { return .lockIn }
        if stabilityProgress > 0 { return .tracking(progress: stabilityProgress) }
        return .idle
    }

    func startMeasuring(arService: ARFaceTrackingService) {
        guard !didStartMeasuring else { return }
        didStartMeasuring = true

        pdService.startMeasuring(arService: arService)

        pdService.$totalPdMm.assign(to: &$totalPdMm)
        pdService.$rightMonoPdMm.assign(to: &$rightMonoPdMm)
        pdService.$leftMonoPdMm.assign(to: &$leftMonoPdMm)
        pdService.$isStable.assign(to: &$isStable)

        arService.$isLookingAtCamera
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLookingAtCamera)

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        Publishers.CombineLatest3($isStable, $isLookingAtCamera, $distanceCm)
            .map { [targetDistanceCm] stable, looking, distance in
                stable && looking && targetDistanceCm.contains(distance)
            }
            .removeDuplicates()
            .sink { [weak self] holding in
                self?.handleHoldCondition(holding)
            }
            .store(in: &cancellables)
    }

    func stopMeasuring() {
        pdService.stopMeasuring()
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func handleHoldCondition(_ holding: Bool) {
        if holding {
            guard holdStart == nil else { return }
            holdStart = Date()
            holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tickHold() }
            }
        } else {
            holdStart = nil
            holdTimer?.invalidate()
            holdTimer = nil
            stabilityProgress = 0
        }
    }

    private func tickHold() {
        guard let start = holdStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        stabilityProgress = min(1.0, elapsed / requiredHoldSeconds)
        if stabilityProgress >= 1.0 {
            holdTimer?.invalidate()
            holdTimer = nil
            confirmPD()
        }
    }

    func confirmPD() {
        guard canConfirm, confirmedResult == nil else { return }
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
