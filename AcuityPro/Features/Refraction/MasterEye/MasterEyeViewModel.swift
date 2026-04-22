import Combine
import SwiftUI

@MainActor
final class MasterEyeViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var leftEyeBlink: Float = 0
    @Published var rightEyeBlink: Float = 0
    @Published var testPhase: BlurTestPhase = .closingRight

    private(set) var dominantEye: Eye?
    private var rightClosedClarity: ClarityRating?
    private var leftClosedClarity: ClarityRating?
    private var cancellables = Set<AnyCancellable>()

    enum BlurTestPhase {
        case closingRight  // close right eye, compare
        case closingLeft   // close left eye, compare
        case result
    }

    enum ClarityRating {
        case noticeable
        case notNoticeable
    }

    func startTest(arService: ARFaceTrackingService) {
        arService.$leftEyeBlink
            .receive(on: DispatchQueue.main)
            .assign(to: &$leftEyeBlink)

        arService.$rightEyeBlink
            .receive(on: DispatchQueue.main)
            .assign(to: &$rightEyeBlink)

        step = .active
        testPhase = .closingRight
    }

    /// User reports how much change they noticed when closing the specified eye.
    func recordClarity(closedEye: Eye, noticeable: Bool) {
        let rating: ClarityRating = noticeable ? .noticeable : .notNoticeable
        switch closedEye {
        case .right: rightClosedClarity = rating
        case .left: leftClosedClarity = rating
        }

        if testPhase == .closingRight {
            testPhase = .closingLeft
        } else {
            determineDominantEye()
        }
    }

    private func determineDominantEye() {
        // The eye whose closure is MORE noticeable is the dominant eye.
        // When you close your dominant eye, you notice a bigger shift.
        switch (rightClosedClarity, leftClosedClarity) {
        case (.noticeable, .notNoticeable):
            dominantEye = .right
        case (.notNoticeable, .noticeable):
            dominantEye = .left
        default:
            dominantEye = .right  // Default to right if equal
        }
        HapticFeedback.distanceLocked()
        testPhase = .result
        step = .complete
    }
}
