import Combine
import SwiftUI

@MainActor
final class NearAddViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var distanceCm: Float = 0
    @Published var isStable: Bool = false

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

        step = .active
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
