import Foundation

/// Which eye is being tested or covered.
enum Eye: String, Codable {
    case left
    case right

    var displayName: String {
        switch self {
        case .left: return "LEFT"
        case .right: return "RIGHT"
        }
    }

    var opposite: Eye {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

/// Which phase of the refraction test the user is currently in.
enum RefractionPhase: Equatable {
    case calibration
    case sphereTest(eye: Eye)
    case cylinderAxisTest(eye: Eye)
    case cylinderPowerTest(eye: Eye)
    case binocularBalance
    case nearAdd
    case intermediateAdd
    case masterEye
    case pupillaryDistance
    case finalRx
}

/// Sub-state within each phase.
enum PhaseStepState: Equatable {
    case instruction
    case active
    case confirmation
    case complete
}

/// Accumulates all measurements collected during a refraction session.
struct RefractionSession {
    var age: Int = 0

    // Sphere far-point measurements
    var rightSphereFarPoint: FarPointMeasurement?
    var leftSphereFarPoint: FarPointMeasurement?

    // Cylinder measurements
    var rightCylinderAxis: Int?          // degrees 1-180
    var rightCylinderFarPoint: FarPointMeasurement?
    var leftCylinderAxis: Int?
    var leftCylinderFarPoint: FarPointMeasurement?

    // Near / intermediate add
    var comfortableReadingDistanceCm: Float?
    var desktopViewingDistanceCm: Float?

    // Binocular balance adjustments (delta applied to sphere)
    var rightSphereAdjustment: Double = 0
    var leftSphereAdjustment: Double = 0

    // Master eye
    var dominantEye: Eye?

    // Pupillary distance
    var pdMm: Double?
    var monoPdRightMm: Double?
    var monoPdLeftMm: Double?
}
