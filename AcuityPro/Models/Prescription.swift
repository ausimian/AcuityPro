import Foundation

/// Refractive prescription for a single eye.
struct EyePrescription: Equatable {
    let sphere: Double          // dioptres (negative = myopia)
    let cylinder: Double        // dioptres (negative convention)
    let axis: Int               // degrees 1-180 (0 if no cylinder)
    let nearAdd: Double?        // positive dioptres for reading
    let intermediateAdd: Double? // positive dioptres for desktop
}

/// Complete prescription output from a refraction session.
struct FullPrescription: Identifiable {
    let id: UUID
    let date: Date
    let rightEye: EyePrescription
    let leftEye: EyePrescription
    let dominantEye: Eye
    let pdMm: Double
    let monoPdRightMm: Double
    let monoPdLeftMm: Double
    let age: Int
    let deviceModel: String

    init(
        rightEye: EyePrescription,
        leftEye: EyePrescription,
        dominantEye: Eye,
        pdMm: Double,
        monoPdRightMm: Double,
        monoPdLeftMm: Double,
        age: Int,
        deviceModel: String,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.rightEye = rightEye
        self.leftEye = leftEye
        self.dominantEye = dominantEye
        self.pdMm = pdMm
        self.monoPdRightMm = monoPdRightMm
        self.monoPdLeftMm = monoPdLeftMm
        self.age = age
        self.deviceModel = deviceModel
    }

    /// Plain text summary suitable for sharing or printing.
    var shareSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        func formatSph(_ val: Double) -> String {
            String(format: "%+.2f", val)
        }
        func formatCyl(_ val: Double) -> String {
            val == 0 ? "DS" : String(format: "%+.2f", val)
        }
        func formatAxis(_ val: Int, cyl: Double) -> String {
            cyl == 0 ? "-" : String(format: "%d°", val)
        }
        func formatAdd(_ val: Double?) -> String {
            guard let v = val else { return "-" }
            return String(format: "+%.2f", v)
        }

        return """
        AcuityPro Refraction Results
        Date: \(formatter.string(from: date))

                 SPH      CYL     AXIS    ADD
        R:    \(formatSph(rightEye.sphere))   \(formatCyl(rightEye.cylinder))    \(formatAxis(rightEye.axis, cyl: rightEye.cylinder))   \(formatAdd(rightEye.nearAdd))
        L:    \(formatSph(leftEye.sphere))   \(formatCyl(leftEye.cylinder))    \(formatAxis(leftEye.axis, cyl: leftEye.cylinder))   \(formatAdd(leftEye.nearAdd))

        PD: \(String(format: "%.1f", pdMm))mm (R: \(String(format: "%.1f", monoPdRightMm)) / L: \(String(format: "%.1f", monoPdLeftMm)))
        Dominant Eye: \(dominantEye.displayName)

        This is a screening tool only and does not replace a clinical eye examination.
        """
    }
}
