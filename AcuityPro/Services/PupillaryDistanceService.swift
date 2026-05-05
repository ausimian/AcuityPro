import Combine
import Foundation
import simd

/// Measures interpupillary distance from ARKit eye transforms.
///
/// Total PD updates whenever both eye positions are available — the
/// inter-eye distance is unaffected by head rotation. Mono PDs only
/// update when the head is level (roll AND yaw within threshold), since
/// a turned head shifts both eyes' x-coordinates relative to the face
/// anchor origin and would otherwise produce asymmetric mono readings.
@MainActor
final class PupillaryDistanceService: ObservableObject {

    /// Convergence rule of thumb: near PD ≈ distance PD − 3 mm,
    /// with the shift split evenly between the two mono values.
    /// Single source of truth for the near-PD derivation; a future
    /// PR can replace this with a working-distance-dependent formula.
    static let nearPdTotalShiftMm: Double = 3.0
    static let nearPdMonoShiftMm: Double = 1.5

    @Published var totalPdMm: Double = 0
    @Published var rightMonoPdMm: Double = 0
    @Published var leftMonoPdMm: Double = 0
    @Published var isStable: Bool = false

    private var pdBuffer: [Double] = []
    private let bufferSize = 30  // Average over ~1 second at 30fps
    private let stabilityThreshold: Double = 0.5  // mm

    private var cancellables = Set<AnyCancellable>()
    private var faceIsLevel: Bool = false

    func startMeasuring(arService: ARFaceTrackingService) {
        pdBuffer.removeAll()

        arService.$faceIsLevel
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.faceIsLevel = level
            }
            .store(in: &cancellables)

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
        // (nose bridge). Only refresh while the face is level — a
        // turned head would skew the readings.
        if faceIsLevel {
            rightMonoPdMm = Double(abs(rightEye.x)) * 1000
            leftMonoPdMm = Double(abs(leftEye.x)) * 1000
        }

        if pdBuffer.count >= bufferSize {
            let mean = avgPd
            let variance = pdBuffer.reduce(0) { $0 + pow($1 - mean, 2) } / Double(pdBuffer.count)
            isStable = sqrt(variance) < stabilityThreshold
        }
    }
}
