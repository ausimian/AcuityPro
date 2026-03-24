import SwiftUI

/// Top-level view that orchestrates the entire refraction test flow.
/// Switches between phase-specific views based on the current state.
struct RefractionCoordinatorView: View {
    @ObservedObject var arService: ARFaceTrackingService
    let age: Int
    @StateObject private var viewModel = RefractionCoordinatorViewModel()

    var body: some View {
        Group {
            switch viewModel.currentPhase {
            case .calibration:
                CalibrationView(arService: arService) {
                    viewModel.advanceToNextPhase()
                }

            case .sphereTest(let eye):
                coverThenTest(eye: eye) {
                    SphereTestView(
                        arService: arService,
                        viewModel: SphereTestViewModel(eye: eye)
                    ) { measurement in
                        viewModel.recordSphereMeasurement(measurement, for: eye)
                    }
                }

            case .cylinderAxisTest(let eye):
                CylinderAxisWrapper(
                    arService: arService,
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

            case .binocularBalance:
                BinocularBalanceView { rightAdj, leftAdj in
                    viewModel.recordBinocularBalance(rightAdjustment: rightAdj, leftAdjustment: leftAdj)
                }

            case .nearAdd:
                NearAddView(
                    arService: arService,
                    viewModel: NearAddViewModel(age: viewModel.session.age)
                ) { distanceCm in
                    viewModel.recordNearDistance(distanceCm)
                }

            case .intermediateAdd:
                IntermediateAddView(
                    arService: arService,
                    viewModel: IntermediateAddViewModel(age: viewModel.session.age)
                ) { distanceCm in
                    viewModel.recordIntermediateDistance(distanceCm)
                }

            case .masterEye:
                MasterEyeView(arService: arService) { dominant in
                    viewModel.recordDominantEye(dominant)
                }

            case .pupillaryDistance:
                PDMeasurementView(arService: arService) { total, right, left in
                    viewModel.recordPD(total: total, right: right, left: left)
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
        }
    }

    /// Wraps a test view with an eye-cover prompt for monocular phases.
    @ViewBuilder
    private func coverThenTest<Content: View>(eye: Eye, @ViewBuilder content: @escaping () -> Content) -> some View {
        EyeCoverTestWrapper(eyeToCover: eye.opposite) {
            content()
        }
    }
}

/// Handles the eye-cover prompt → test transition for monocular phases.
private struct EyeCoverTestWrapper<Content: View>: View {
    let eyeToCover: Eye
    @ViewBuilder let content: () -> Content
    @State private var ready = false

    var body: some View {
        if ready {
            content()
        } else {
            EyeCoverPromptView(eyeToCover: eyeToCover) {
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
    let eye: Eye
    let onComplete: (_ axis: Int?, _ measurement: FarPointMeasurement?) -> Void

    @StateObject private var cylVM: CylinderTestViewModel

    init(arService: ARFaceTrackingService, eye: Eye,
         onComplete: @escaping (_ axis: Int?, _ measurement: FarPointMeasurement?) -> Void) {
        self.arService = arService
        self.eye = eye
        self.onComplete = onComplete
        self._cylVM = StateObject(wrappedValue: CylinderTestViewModel(eye: eye))
    }

    var body: some View {
        Group {
            if cylVM.axisStep != .complete {
                CylinderAxisView(viewModel: cylVM)
            } else if cylVM.selectedAxis != nil && cylVM.powerStep != .complete {
                CylinderPowerView(arService: arService, viewModel: cylVM)
            } else {
                Color.clear.onAppear {
                    onComplete(cylVM.selectedAxis, cylVM.confirmedMeasurement)
                }
            }
        }
    }
}
