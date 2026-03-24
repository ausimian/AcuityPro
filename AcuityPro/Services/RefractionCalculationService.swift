import Foundation

/// Computes refractive power from far-point measurements and age-based additions.
struct RefractionCalculationService {

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

    /// Intermediate addition (50% of near add).
    func intermediateAdd(age: Int) -> Double {
        NearAddTable.intermediateAdd(forAge: age)
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

        let nAdd = session.age >= 40 ? nearAdd(age: session.age) : nil as Double?
        let iAdd = session.age >= 40 ? intermediateAdd(age: session.age) : nil as Double?

        return FullPrescription(
            rightEye: EyePrescription(
                sphere: roundToQuarter(rightSphere),
                cylinder: roundToQuarter(rightCyl),
                axis: rightAxis,
                nearAdd: nAdd,
                intermediateAdd: iAdd
            ),
            leftEye: EyePrescription(
                sphere: roundToQuarter(leftSphere),
                cylinder: roundToQuarter(leftCyl),
                axis: leftAxis,
                nearAdd: nAdd,
                intermediateAdd: iAdd
            ),
            dominantEye: session.dominantEye ?? .right,
            pdMm: session.pdMm ?? 63.0,
            monoPdRightMm: session.monoPdRightMm ?? 31.5,
            monoPdLeftMm: session.monoPdLeftMm ?? 31.5,
            age: session.age,
            deviceModel: deviceModel
        )
    }

    /// Rounds a dioptric value to the nearest 0.25D step (clinical convention).
    private func roundToQuarter(_ value: Double) -> Double {
        (value * 4).rounded() / 4
    }
}
