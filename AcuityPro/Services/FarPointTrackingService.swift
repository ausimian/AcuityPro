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
    /// 0..1 jitter-derived progress used to drive a guidance-circle arc.
    /// Grows as the user settles into a stable distance and reaches 1
    /// when standard deviation across the window hits zero.
    @Published var stabilityProgress: Double = 0

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
    func confirmFarPoint(eye: Eye, meridian: MeridianType, outOfRange: Bool = false) -> FarPointMeasurement {
        FarPointMeasurement(
            distanceCm: currentDistanceCm,
            eye: eye,
            meridian: meridian,
            outOfRange: outOfRange
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

        if distanceWindow.count >= stabilityWindowSize {
            let stdDev = standardDeviation(distanceWindow)
            isStable = stdDev < stabilityThresholdCm
            stabilityProgress = Double(max(0, 1 - stdDev / stabilityThresholdCm))
        } else {
            isStable = false
            // While the window fills, ramp progress slowly from 0 toward
            // 0.5 so the user sees the guidance ring respond immediately.
            stabilityProgress = Double(distanceWindow.count) / Double(stabilityWindowSize) * 0.5
        }
    }

    private func standardDeviation(_ values: [Float]) -> Float {
        let count = Float(values.count)
        let mean = values.reduce(0, +) / count
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / count
        return sqrt(variance)
    }
}
