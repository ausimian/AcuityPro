import Combine
import Foundation

/// Tracks distance in real time during far-point seeking and provides
/// stability detection for confirming measurements.
@MainActor
final class FarPointTrackingService: ObservableObject {

    // MARK: - Published State

    @Published var currentDistanceCm: Float = 0
    @Published var isStable: Bool = false
    @Published var estimatedDioptres: Double = 0

    // MARK: - Configuration

    private let stabilityWindowSize = 15       // frames to consider
    private let stabilityThresholdCm: Float = 1.5  // max std dev for "stable"

    // MARK: - Private

    private var distanceWindow: [Float] = []
    private var cancellables = Set<AnyCancellable>()
    private let calculator = RefractionCalculationService()

    // MARK: - Monitoring

    func startTracking(arService: ARFaceTrackingService) {
        distanceWindow.removeAll()

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .sink { [weak self] distance in
                self?.handleDistanceUpdate(distance)
            }
            .store(in: &cancellables)
    }

    func stopTracking() {
        cancellables.removeAll()
        distanceWindow.removeAll()
    }

    /// Snapshot the current distance as a confirmed far-point measurement.
    func confirmFarPoint(eye: Eye, meridian: MeridianType) -> FarPointMeasurement {
        FarPointMeasurement(
            distanceCm: currentDistanceCm,
            eye: eye,
            meridian: meridian
        )
    }

    // MARK: - Private

    private func handleDistanceUpdate(_ distance: Float) {
        currentDistanceCm = distance
        estimatedDioptres = calculator.spherePower(farPointCm: distance)

        distanceWindow.append(distance)
        if distanceWindow.count > stabilityWindowSize {
            distanceWindow.removeFirst()
        }

        isStable = distanceWindow.count >= stabilityWindowSize && standardDeviation(distanceWindow) < stabilityThresholdCm
    }

    private func standardDeviation(_ values: [Float]) -> Float {
        let count = Float(values.count)
        let mean = values.reduce(0, +) / count
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / count
        return sqrt(variance)
    }
}
