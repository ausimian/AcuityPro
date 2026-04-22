import ARKit
import Combine
import simd

/// Manages an ARKit face tracking session, publishing real-time distance
/// and eye blink values. This is the core sensing layer of the app.
final class ARFaceTrackingService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var distanceCm: Float = 0
    @Published var isTrackingFace: Bool = false
    @Published var leftEyeBlink: Float = 0    // 0.0 (open) to 1.0 (closed)
    @Published var rightEyeBlink: Float = 0
    @Published var faceIsLevel: Bool = false   // True if head tilt < threshold

    /// 3D position of each eye relative to the face anchor, in meters.
    /// Used for pupillary distance measurement.
    @Published var leftEyePosition: SIMD3<Float>?
    @Published var rightEyePosition: SIMD3<Float>?

    // MARK: - Configuration

    static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    // MARK: - Private

    private let session = ARSession()
    private var distanceBuffer: [Float] = []
    private let bufferSize = 10  // Rolling average over 10 frames
    private let tiltThresholdRadians: Float = 0.15  // ~8.6 degrees

    // MARK: - Session Control

    func startSession() {
        guard ARFaceTrackingService.isSupported else { return }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        session.delegate = self
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stopSession() {
        session.pause()
        distanceBuffer.removeAll()
        DispatchQueue.main.async {
            self.isTrackingFace = false
        }
    }

    // MARK: - Distance Smoothing

    private func smoothedDistance(_ rawCm: Float) -> Float {
        distanceBuffer.append(rawCm)
        if distanceBuffer.count > bufferSize {
            distanceBuffer.removeFirst()
        }
        return distanceBuffer.reduce(0, +) / Float(distanceBuffer.count)
    }
}

// MARK: - ARSessionDelegate

extension ARFaceTrackingService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            return
        }

        // Distance: Calculate from camera to face, then adjust for eye-to-screen distance
        // ARKit gives us camera-to-face distance (Z component, negative because camera faces user)
        let cameraToFaceZ = -faceAnchor.transform.columns.3.z * 100  // in cm
        
        // On iPhones, the camera sits above the screen. When the user looks at the center
        // of the screen (not the camera), we need to account for the vertical offset.
        // The camera is typically ~1.5-2cm above the top edge, and the user looks at
        // approximately the center of the screen.
        //
        // This creates a right triangle where:
        // - Z distance (depth) = camera to face
        // - Y distance (vertical) = camera to center of screen
        // - Hypotenuse = actual eye-to-viewing-point distance
        
        let cameraOffsetFromScreenCenterCm: Float = 8.0  // Approximate for most iPhones
        
        // Calculate actual viewing distance using Pythagorean theorem
        let actualDistanceCm = sqrt(pow(cameraToFaceZ, 2) + pow(cameraOffsetFromScreenCenterCm, 2))
        let smoothed = smoothedDistance(actualDistanceCm)

        // Eye blinks from blend shapes
        let leftBlink = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let rightBlink = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0

        // Head tilt: extract roll from the face transform
        let col0 = faceAnchor.transform.columns.0
        let roll = atan2(col0.y, col0.x)
        let isLevel = abs(roll) < tiltThresholdRadians

        // Eye positions from eye transforms (relative to face anchor, in meters)
        let leftEyeCol = faceAnchor.leftEyeTransform.columns.3
        let rightEyeCol = faceAnchor.rightEyeTransform.columns.3
        let leftEyePos = SIMD3<Float>(leftEyeCol.x, leftEyeCol.y, leftEyeCol.z)
        let rightEyePos = SIMD3<Float>(rightEyeCol.x, rightEyeCol.y, rightEyeCol.z)

        DispatchQueue.main.async {
            self.distanceCm = smoothed
            self.isTrackingFace = faceAnchor.isTracked
            self.leftEyeBlink = leftBlink
            self.rightEyeBlink = rightBlink
            self.faceIsLevel = isLevel
            self.leftEyePosition = leftEyePos
            self.rightEyePosition = rightEyePos
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isTrackingFace = false
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.isTrackingFace = false
        }
    }
}
