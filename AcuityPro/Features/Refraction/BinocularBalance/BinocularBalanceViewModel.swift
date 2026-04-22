import Combine
import SwiftUI

/// Simplified HIC (Humphrey's Immediate Contrast) binocular balance test.
/// V1: Comparative clarity question to fine-tune sphere balance between eyes.
@MainActor
final class BinocularBalanceViewModel: ObservableObject {

    @Published var step: PhaseStepState = .instruction
    @Published var currentIteration = 0

    private(set) var rightAdjustment: Double = 0
    private(set) var leftAdjustment: Double = 0
    private let maxIterations = 3
    private let adjustmentStep: Double = 0.25  // quarter dioptre steps

    func startTest() {
        step = .active
        currentIteration = 0
    }

    /// User reports which eye sees more clearly.
    /// The clearer eye gets a slight minus adjustment (fog) to balance.
    func reportClearer(eye: Eye?) {
        currentIteration += 1

        if let eye {
            switch eye {
            case .right: rightAdjustment -= adjustmentStep
            case .left: leftAdjustment -= adjustmentStep
            }
        }

        if currentIteration >= maxIterations || eye == nil {
            HapticFeedback.distanceLocked()
            step = .complete
        }
    }
}
