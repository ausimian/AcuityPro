import Combine
import SwiftUI

@MainActor
final class NearAddViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var distanceCm: Float = 0
    @Published var isStable: Bool = false
    @Published var stabilityProgress: Double = 0

    private(set) var confirmedDistanceCm: Float?
    private let trackingService = FarPointTrackingService()
    let age: Int

    init(age: Int) {
        self.age = age
    }

    func startTracking(arService: ARFaceTrackingService) {
        trackingService.startTracking(arService: arService)

        trackingService.$currentDistanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        trackingService.$isStable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isStable)

        trackingService.$stabilityProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$stabilityProgress)

        step = .active
    }

    var guidanceState: GuidanceState {
        if isStable { return .lockIn }
        if stabilityProgress < 0.05 { return .idle }
        return .tracking(progress: stabilityProgress)
    }

    func stopTracking() {
        trackingService.stopTracking()
    }

    func confirmDistance() {
        confirmedDistanceCm = distanceCm
        HapticFeedback.distanceLocked()
        step = .complete
    }

    var computedNearAdd: Double {
        NearAddTable.nearAdd(forAge: age)
    }
}
