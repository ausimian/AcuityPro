import SwiftUI

/// Top-level view that orchestrates the entire refraction test flow.
/// Switches between phase-specific views based on the current state.
struct RefractionCoordinatorView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    let age: Int
    let symptomProfile: VisionSymptomProfile?
    @StateObject private var viewModel = RefractionCoordinatorViewModel()

    var body: some View {
        Group {
            switch viewModel.currentPhase {
            case .calibration:
                CalibrationView(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator
                ) {
                    viewModel.advanceToNextPhase()
                }

            case .sphereTest(let eye):
                coverThenTest(eye: eye) {
                    SphereTestView(
                        arService: arService,
                        voiceCoordinator: voiceCoordinator,
                        viewModel: SphereTestViewModel(eye: eye)
                    ) { measurement in
                        viewModel.recordSphereMeasurement(measurement, for: eye)
                    }
                }

            case .cylinderAxisTest(let eye):
                CylinderAxisWrapper(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator,
                    eye: eye
                ) { axis, measurement in
                    viewModel.recordCylinderResult(axis: axis, measurement: measurement, for: eye)
                }

            case .cylinderPowerTest:
                // Cylinder power is handled within the CylinderAxisWrapper.
                // This state is skipped over by recordCylinderResult.
                Color.clear.onAppear {
                    viewModel.advanceToNextPhase()
                }

            case .nearAdd:
                NearAddView(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator,
                    viewModel: NearAddViewModel(age: viewModel.session.age)
                ) { distanceCm in
                    viewModel.recordNearDistance(distanceCm)
                }

            case .binocularBalance, .intermediateAdd, .masterEye:
                // Phases removed from phaseOrder in v2.3 — should never render.
                // Kept as enum cases so the corresponding view files remain
                // compilable for a future re-introduction.
                Color.clear.onAppear {
                    viewModel.advanceToNextPhase()
                }

            case .pupillaryDistance:
                PDMeasurementView(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator
                ) { result in
                    viewModel.recordPD(result)
                }

            case .finalRx:
                PrescriptionResultsView(
                    viewModel: PrescriptionResultsViewModel(
                        coordinator: viewModel
                    )
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentPhase)
        .onAppear {
            viewModel.session.age = age
            viewModel.session.symptomProfile = symptomProfile
        }
    }

    /// Wraps a test view with an eye-cover prompt for monocular phases.
    @ViewBuilder
    private func coverThenTest<Content: View>(eye: Eye, @ViewBuilder content: @escaping () -> Content) -> some View {
        EyeCoverTestWrapper(eyeToCover: eye.opposite, voiceCoordinator: voiceCoordinator) {
            content()
        }
    }
}

/// Handles the eye-cover prompt → test transition for monocular phases.
private struct EyeCoverTestWrapper<Content: View>: View {
    let eyeToCover: Eye
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    @ViewBuilder let content: () -> Content
    @State private var ready = false

    var body: some View {
        if ready {
            content()
        } else {
            EyeCoverPromptView(eyeToCover: eyeToCover, voiceCoordinator: voiceCoordinator) {
                ready = true
            }
        }
    }
}

/// Combined cylinder axis → power flow for one eye.
/// Handles axis selection, then transitions to power measurement,
/// then reports both results via a single callback.
private struct CylinderAxisWrapper: View {
    @ObservedObject var arService: ARFaceTrackingService
    @ObservedObject var voiceCoordinator: VoiceCoordinator
    let eye: Eye
    let onComplete: (_ axis: Int?, _ measurement: FarPointMeasurement?) -> Void

    @StateObject private var cylVM: CylinderTestViewModel

    init(arService: ARFaceTrackingService,
         voiceCoordinator: VoiceCoordinator,
         eye: Eye,
         onComplete: @escaping (_ axis: Int?, _ measurement: FarPointMeasurement?) -> Void) {
        self.arService = arService
        self.voiceCoordinator = voiceCoordinator
        self.eye = eye
        self.onComplete = onComplete
        self._cylVM = StateObject(wrappedValue: CylinderTestViewModel(eye: eye))
    }

    var body: some View {
        Group {
            if cylVM.axisStep != .complete {
                CylinderAxisView(viewModel: cylVM, voiceCoordinator: voiceCoordinator)
            } else if cylVM.selectedAxis != nil && cylVM.powerStep != .complete {
                CylinderPowerView(
                    arService: arService,
                    voiceCoordinator: voiceCoordinator,
                    viewModel: cylVM
                )
            } else {
                Color.clear.onAppear {
                    onComplete(cylVM.selectedAxis, cylVM.confirmedMeasurement)
                }
            }
        }
    }
}
