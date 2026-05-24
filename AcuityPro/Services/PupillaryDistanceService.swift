import Combine
import Foundation
import simd

/// Measures interpupillary distance from ARKit eye transforms.
///
/// Total PD and mono PDs both update whenever eye positions are
/// available. The eye transforms are reported in the face anchor's
/// local frame, so X coords stay stable under head rotation — no
/// head-pose gate is needed here. The VM gates *capture* on gaze
/// alignment to ensure the reading represents a forward-facing pose.
@MainActor
final class PupillaryDistanceService: ObservableObject {

    /// Convergence rule of thumb: near PD ≈ distance PD − 3 mm,
    /// with the shift split evenly between the two mono values.
    /// Single source of truth for the near-PD derivation; a future
    /// PR can replace this with a working-distance-dependent formula.
    nonisolated static let nearPdTotalShiftMm: Double = 3.0
    nonisolated static let nearPdMonoShiftMm: Double = 1.5

    @Published var totalPdMm: Double = 0
    @Published var rightMonoPdMm: Double = 0
    @Published var leftMonoPdMm: Double = 0
    @Published var isStable: Bool = false

    private var pdBuffer: [Double] = []
    private let bufferSize = 30  // Average over ~1 second at 30fps
    private let stabilityThreshold: Double = 0.5  // mm

    private var cancellables = Set<AnyCancellable>()

    func startMeasuring(arService: ARFaceTrackingService) {
        pdBuffer.removeAll()

        // `zip` rather than `combineLatest`: ARFaceTrackingService
        // assigns left then right inside one main-queue block, so
        // combineLatest fires twice per frame (once with stale right,
        // once with both fresh). zip waits for matched pairs and
        // emits exactly once per frame.
        arService.$leftEyePosition
            .zip(arService.$rightEyePosition)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] leftPos, rightPos in
                guard let self, let left = leftPos, let right = rightPos else { return }
                self.updatePD(leftEye: left, rightEye: right)
            }
            .store(in: &cancellables)
    }

    func stopMeasuring() {
        cancellables.removeAll()
        pdBuffer.removeAll()
    }

    private func updatePD(leftEye: SIMD3<Float>, rightEye: SIMD3<Float>) {
        let pdMeters = simd_distance(leftEye, rightEye)
        let pdMm = Double(pdMeters) * 1000

        pdBuffer.append(pdMm)
        if pdBuffer.count > bufferSize {
            pdBuffer.removeFirst()
        }

        let avgPd = pdBuffer.reduce(0, +) / Double(pdBuffer.count)
        totalPdMm = avgPd

        // Mono PDs: X distance from each eye to the face anchor origin
        // (nose bridge). Eye transforms are in face-local space, so
        // these stay stable regardless of head pose.
        rightMonoPdMm = Double(abs(rightEye.x)) * 1000
        leftMonoPdMm = Double(abs(leftEye.x)) * 1000

        if pdBuffer.count >= bufferSize {
            let mean = avgPd
            let variance = pdBuffer.reduce(0) { $0 + pow($1 - mean, 2) } / Double(pdBuffer.count)
            isStable = sqrt(variance) < stabilityThreshold
        }
    }
}
