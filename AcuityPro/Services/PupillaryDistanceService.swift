import Combine
import Foundation
import simd

/// Measures interpupillary distance from ARKit eye transforms.
@MainActor
final class PupillaryDistanceService: ObservableObject {

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

        // Combine left and right eye position updates
        arService.$leftEyePosition
            .combineLatest(arService.$rightEyePosition)
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
        // Distance between eyes in meters, convert to mm
        let pdMeters = simd_distance(leftEye, rightEye)
        let pdMm = Double(pdMeters) * 1000

        pdBuffer.append(pdMm)
        if pdBuffer.count > bufferSize {
            pdBuffer.removeFirst()
        }

        let avgPd = pdBuffer.reduce(0, +) / Double(pdBuffer.count)
        totalPdMm = avgPd

        // Mono PDs: X distance from each eye to the face anchor origin (nose bridge)
        rightMonoPdMm = Double(abs(rightEye.x)) * 1000
        leftMonoPdMm = Double(abs(leftEye.x)) * 1000

        // Check stability
        if pdBuffer.count >= bufferSize {
            let mean = avgPd
            let variance = pdBuffer.reduce(0) { $0 + pow($1 - mean, 2) } / Double(pdBuffer.count)
            isStable = sqrt(variance) < stabilityThreshold
        }
    }
}
