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
    /// True when the user's gaze (faceAnchor.lookAtPoint) is within
    /// `gazeAngleToleranceRadians` of the camera direction in face-local
    /// space. Used by the PD phase to gate confirm on the user actually
    /// looking at the on-screen target dot, not just holding the phone
    /// somewhere in front of them.
    @Published var isLookingAtCamera: Bool = false

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
    /// Angular tolerance between gaze direction and camera direction
    /// for `isLookingAtCamera` to fire. 18° is forgiving enough for
    /// real-world holding postures (a reading angle still passes) while
    /// rejecting clearly off-target gazes.
    private let gazeAngleToleranceCos: Float = 0.95  // cos(~18°)

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

        // Head pose: extract roll (z-axis tilt) and yaw (left/right turn)
        // from the face transform. Both must be within threshold for the
        // face to count as "level" — yaw matters for mono-PD because a
        // turned head shifts both eyes' x-positions in opposite directions
        // relative to the face anchor origin (nose bridge).
        let col0 = faceAnchor.transform.columns.0
        let roll = atan2(col0.y, col0.x)
        let yaw = atan2(col0.z, col0.x)
        let isLevel = abs(roll) < tiltThresholdRadians
            && abs(yaw) < tiltThresholdRadians

        // Eye positions from eye transforms (relative to face anchor, in meters)
        let leftEyeCol = faceAnchor.leftEyeTransform.columns.3
        let rightEyeCol = faceAnchor.rightEyeTransform.columns.3
        let leftEyePos = SIMD3<Float>(leftEyeCol.x, leftEyeCol.y, leftEyeCol.z)
        let rightEyePos = SIMD3<Float>(rightEyeCol.x, rightEyeCol.y, rightEyeCol.z)

        // Gaze vs camera. Project the camera position into face-local
        // space and compare against lookAtPoint (also face-local) — the
        // angle between those two direction vectors tells us how far
        // off-axis the user's gaze is from the camera.
        var lookingAtCamera = false
        if let camTransform = session.currentFrame?.camera.transform {
            let cameraInWorld = SIMD4<Float>(camTransform.columns.3.x,
                                             camTransform.columns.3.y,
                                             camTransform.columns.3.z,
                                             1)
            let cameraInFace4 = simd_inverse(faceAnchor.transform) * cameraInWorld
            let cameraInFace = SIMD3<Float>(cameraInFace4.x, cameraInFace4.y, cameraInFace4.z)
            let lookAt = faceAnchor.lookAtPoint
            let lookAtLen = simd_length(lookAt)
            let camLen = simd_length(cameraInFace)
            if lookAtLen > 1e-4 && camLen > 1e-4 {
                let cosAngle = simd_dot(lookAt, cameraInFace) / (lookAtLen * camLen)
                lookingAtCamera = cosAngle > gazeAngleToleranceCos
            }
        }
        let isLookingAtCameraNow = lookingAtCamera

        DispatchQueue.main.async {
            self.distanceCm = smoothed
            self.isTrackingFace = faceAnchor.isTracked
            self.leftEyeBlink = leftBlink
            self.rightEyeBlink = rightBlink
            self.faceIsLevel = isLevel
            self.isLookingAtCamera = isLookingAtCameraNow
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
