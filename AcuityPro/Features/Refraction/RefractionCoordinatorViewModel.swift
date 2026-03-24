import Combine
import SwiftUI

@MainActor
final class RefractionCoordinatorViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentPhase: RefractionPhase = .calibration
    @Published var session = RefractionSession()

    // MARK: - Services

    let calculationService = RefractionCalculationService()

    // MARK: - Result

    @Published var prescription: FullPrescription?

    // MARK: - Phase Transitions

    /// Ordered sequence of all refraction phases.
    private static let phaseOrder: [RefractionPhase] = [
        .calibration,
        .sphereTest(eye: .right),
        .cylinderAxisTest(eye: .right),
        .cylinderPowerTest(eye: .right),
        .sphereTest(eye: .left),
        .cylinderAxisTest(eye: .left),
        .cylinderPowerTest(eye: .left),
        .binocularBalance,
        .nearAdd,
        .intermediateAdd,
        .masterEye,
        .pupillaryDistance,
        .finalRx
    ]

    func advanceToNextPhase() {
        guard let currentIndex = Self.phaseOrder.firstIndex(of: currentPhase) else {
            return
        }
        let nextIndex = currentIndex + 1
        guard nextIndex < Self.phaseOrder.count else { return }
        currentPhase = Self.phaseOrder[nextIndex]
    }

    /// Skip the current phase (e.g. skip cylinder if no astigmatism).
    func skipToPhaseAfter(_ phase: RefractionPhase) {
        currentPhase = phase
        advanceToNextPhase()
    }

    // MARK: - Measurement Recording

    func recordSphereMeasurement(_ measurement: FarPointMeasurement?, for eye: Eye) {
        switch eye {
        case .right: session.rightSphereFarPoint = measurement
        case .left: session.leftSphereFarPoint = measurement
        }
        advanceToNextPhase()
    }

    func recordCylinderAxis(_ axis: Int?, for eye: Eye) {
        if let axis {
            switch eye {
            case .right: session.rightCylinderAxis = axis
            case .left: session.leftCylinderAxis = axis
            }
            advanceToNextPhase()
        } else {
            // No astigmatism — skip cylinder power test for this eye
            skipToPhaseAfter(.cylinderPowerTest(eye: eye))
        }
    }

    func recordCylinderMeasurement(_ measurement: FarPointMeasurement?, for eye: Eye) {
        switch eye {
        case .right: session.rightCylinderFarPoint = measurement
        case .left: session.leftCylinderFarPoint = measurement
        }
        advanceToNextPhase()
    }

    /// Combined cylinder result — records both axis and power, then skips past cylinderPowerTest.
    func recordCylinderResult(axis: Int?, measurement: FarPointMeasurement?, for eye: Eye) {
        if let axis {
            switch eye {
            case .right:
                session.rightCylinderAxis = axis
                session.rightCylinderFarPoint = measurement
            case .left:
                session.leftCylinderAxis = axis
                session.leftCylinderFarPoint = measurement
            }
        }
        // Skip past both cylinderAxisTest and cylinderPowerTest for this eye
        skipToPhaseAfter(.cylinderPowerTest(eye: eye))
    }

    func recordBinocularBalance(rightAdjustment: Double, leftAdjustment: Double) {
        session.rightSphereAdjustment = rightAdjustment
        session.leftSphereAdjustment = leftAdjustment
        advanceToNextPhase()
    }

    func recordDominantEye(_ eye: Eye) {
        session.dominantEye = eye
        advanceToNextPhase()
    }

    func recordPD(total: Double, right: Double, left: Double) {
        session.pdMm = total
        session.monoPdRightMm = right
        session.monoPdLeftMm = left
        advanceToNextPhase()
    }

    func recordNearDistance(_ distanceCm: Float) {
        session.comfortableReadingDistanceCm = distanceCm
        advanceToNextPhase()
    }

    func recordIntermediateDistance(_ distanceCm: Float) {
        session.desktopViewingDistanceCm = distanceCm
        advanceToNextPhase()
    }

    func computeFinalPrescription() {
        let deviceModel = deviceModelName()
        prescription = calculationService.computePrescription(from: session, deviceModel: deviceModel)
    }

    func resetTest() {
        session = RefractionSession()
        prescription = nil
        currentPhase = .calibration
    }

    // MARK: - Helpers

    private func deviceModelName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
