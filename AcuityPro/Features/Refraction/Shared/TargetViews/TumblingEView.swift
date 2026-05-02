import SwiftUI

/// A tumbling E optotype at a given size and rotation.
/// Used as the far-point target — the user moves the phone until
/// the prongs of the E become clearly distinguishable.
struct TumblingEView: View {
    let size: CGFloat
    let direction: TumblingEDirection
    /// Gaussian blur radius applied to the rendered glyph in points.
    /// Used to fog accommodation during sphere measurement — see optometrist
    /// rationale (start from blur, like focusing a telescope eyepiece).
    var blurRadius: CGFloat = 0

    var body: some View {
        TumblingEShape()
            .fill(Color.primary)
            .frame(width: size, height: size)
            .blur(radius: blurRadius)
            .rotationEffect(direction.rotation)
    }
}

enum TumblingEDirection: CaseIterable {
    case right, down, left, up

    var rotation: Angle {
        switch self {
        case .right: return .degrees(0)
        case .down: return .degrees(90)
        case .left: return .degrees(180)
        case .up: return .degrees(270)
        }
    }

    static var random: TumblingEDirection {
        allCases.randomElement()!
    }
}

/// A 5×5 grid tumbling E shape (prongs pointing right in the default orientation).
struct TumblingEShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cellW = rect.width / 5
        let cellH = rect.height / 5

        var path = Path()
        // The E is drawn on a 5×5 grid with prongs pointing right:
        //  █ █ █ █ █
        //  █ . . . .
        //  █ █ █ █ █
        //  █ . . . .
        //  █ █ █ █ █

        // Top bar (row 0)
        path.addRect(CGRect(x: 0, y: 0, width: cellW * 5, height: cellH))
        // Spine (column 0, full height)
        path.addRect(CGRect(x: 0, y: 0, width: cellW, height: cellH * 5))
        // Middle bar (row 2)
        path.addRect(CGRect(x: 0, y: cellH * 2, width: cellW * 5, height: cellH))
        // Bottom bar (row 4)
        path.addRect(CGRect(x: 0, y: cellH * 4, width: cellW * 5, height: cellH))

        return path
    }
}
