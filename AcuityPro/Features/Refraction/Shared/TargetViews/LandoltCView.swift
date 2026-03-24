import SwiftUI

/// A Landolt C optotype — a ring with a gap — used as the far-point target.
/// The gap is always at the right side; the target is a fixed on-screen size
/// and does NOT scale with distance. The user moves the phone until they can
/// resolve the gap.
struct LandoltCView: View {
    var size: CGFloat = 80
    var strokeWidth: CGFloat = 16

    var body: some View {
        LandoltCShape(gapAngle: .degrees(0), gapSize: .degrees(45))
            .stroke(Color.primary, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: size, height: size)
    }
}

/// Custom shape for a Landolt C — a circle with a gap at a specified angle.
struct LandoltCShape: Shape {
    let gapAngle: Angle   // center of the gap
    let gapSize: Angle    // angular width of the gap

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let startAngle = gapAngle + gapSize / 2
        let endAngle = gapAngle - gapSize / 2 + .degrees(360)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
