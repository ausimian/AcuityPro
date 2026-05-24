import Foundation

/// Computes refractive power from far-point measurements and age-based additions.
struct RefractionCalculationService {

    /// Population averages used when a session is missing PD data
    /// (test was abandoned mid-flow). The near defaults are derived
    /// from these via `PupillaryDistanceService.nearPd*ShiftMm`.
    private let defaultDistancePdMm: Double = 63.0
    private let defaultDistanceMonoPdMm: Double = 31.5

    /// Sphere power from far-point distance.
    /// Returns negative dioptres for myopia, 0 for emmetropia.
    /// - Parameter farPointCm: the distance in cm at which the target became clear
    func spherePower(farPointCm: Float) -> Double {
        guard farPointCm > 0 else { return 0 }
        // F = 1/f where f is in metres. Negative convention for myopia.
        return -(100.0 / Double(farPointCm))
    }

    /// Cylinder power from the difference between sphere and meridian far points.
    /// Returns the additional dioptric power in the perpendicular meridian.
    func cylinderPower(sphereFarPointCm: Float, meridianFarPointCm: Float) -> Double {
        let sphereD = spherePower(farPointCm: sphereFarPointCm)
        let meridianD = spherePower(farPointCm: meridianFarPointCm)
        return meridianD - sphereD
    }

    /// Age-based near addition for presbyopia.
    func nearAdd(age: Int) -> Double {
        NearAddTable.nearAdd(forAge: age)
    }

    /// Intermediate addition (60% of near add — desktop ≈ 0.6 × reading distance).
    func intermediateAdd(fromNearAdd nearAdd: Double) -> Double {
        NearAddTable.intermediateAdd(fromNearAdd: nearAdd)
    }

    /// Compiles a full prescription from all session measurements.
    func computePrescription(from session: RefractionSession, deviceModel: String) -> FullPrescription {
        let rightSphere = (session.rightSphereFarPoint?.dioptres ?? 0) + session.rightSphereAdjustment
        let leftSphere = (session.leftSphereFarPoint?.dioptres ?? 0) + session.leftSphereAdjustment

        let rightCyl: Double
        let rightAxis: Int
        if let sphereFP = session.rightSphereFarPoint,
           let cylFP = session.rightCylinderFarPoint,
           let axis = session.rightCylinderAxis {
            rightCyl = cylinderPower(sphereFarPointCm: sphereFP.distanceCm, meridianFarPointCm: cylFP.distanceCm)
            rightAxis = axis
        } else {
            rightCyl = 0
            rightAxis = 0
        }

        let leftCyl: Double
        let leftAxis: Int
        if let sphereFP = session.leftSphereFarPoint,
           let cylFP = session.leftCylinderFarPoint,
           let axis = session.leftCylinderAxis {
            leftCyl = cylinderPower(sphereFarPointCm: sphereFP.distanceCm, meridianFarPointCm: cylFP.distanceCm)
            leftAxis = axis
        } else {
            leftCyl = 0
            leftAxis = 0
        }

        let nAdd: Double? = session.age >= 40 ? nearAdd(age: session.age) : nil
        let iAdd: Double? = nAdd.map(intermediateAdd(fromNearAdd:))

        return FullPrescription(
            rightEye: EyePrescription(
                sphere: roundToQuarter(rightSphere),
                cylinder: roundToQuarter(rightCyl),
                axis: rightAxis,
                nearAdd: nAdd,
                intermediateAdd: iAdd,
                sphereOutOfRange: session.rightSphereFarPoint?.outOfRange ?? false
            ),
            leftEye: EyePrescription(
                sphere: roundToQuarter(leftSphere),
                cylinder: roundToQuarter(leftCyl),
                axis: leftAxis,
                nearAdd: nAdd,
                intermediateAdd: iAdd,
                sphereOutOfRange: session.leftSphereFarPoint?.outOfRange ?? false
            ),
            dominantEye: session.dominantEye ?? .right,
            pdMm: session.pdMm ?? defaultDistancePdMm,
            monoPdRightMm: session.monoPdRightMm ?? defaultDistanceMonoPdMm,
            monoPdLeftMm: session.monoPdLeftMm ?? defaultDistanceMonoPdMm,
            nearPdMm: session.nearPdMm
                ?? defaultDistancePdMm - PupillaryDistanceService.nearPdTotalShiftMm,
            monoNearPdRightMm: session.monoNearPdRightMm
                ?? defaultDistanceMonoPdMm - PupillaryDistanceService.nearPdMonoShiftMm,
            monoNearPdLeftMm: session.monoNearPdLeftMm
                ?? defaultDistanceMonoPdMm - PupillaryDistanceService.nearPdMonoShiftMm,
            age: session.age,
            deviceModel: deviceModel,
            symptomProfile: session.symptomProfile
        )
    }

    /// Rounds a dioptric value to the nearest 0.25D step (clinical convention).
    private func roundToQuarter(_ value: Double) -> Double {
        (value * 4).rounded() / 4
    }
}
