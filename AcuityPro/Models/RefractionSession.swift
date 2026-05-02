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

/// Self-reported symptom profile collected during onboarding.
/// Used to flag users whose refractive error TrueDepth under-detects
/// (hyperopes cannot produce a measurable far point inside the test range).
enum VisionSymptomProfile: String, Codable, CaseIterable {
    case myope
    case hyperope
    case emmetrope
    case agingHyperope

    var prompt: String {
        switch self {
        case .myope:          return "Near is clear, far is harder"
        case .hyperope:       return "Far is clear, near is harder"
        case .emmetrope:      return "Both are mostly clear"
        case .agingHyperope:  return "Both are blurry"
        }
    }
}

/// Accumulates all measurements collected during a refraction session.
struct RefractionSession {
    var age: Int = 0
    var symptomProfile: VisionSymptomProfile?

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
