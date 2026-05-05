import SwiftUI

/// Drives the look of the shared `GuidanceCircleView`.
///
/// Per the consultant's "Green Circle of Certainty" UX:
///  - `idle`       — slow pulse, awaiting input
///  - `listening`  — ring expands, accent colour (Stage 7 voice hook)
///  - `tracking`   — ring tightens, an orange arc fills as the user settles
///  - `lockIn`     — full green ring; the view fires a snap animation +
///                   success haptic on the transition into this state
enum GuidanceState: Equatable {
    case idle
    case listening
    case tracking(progress: Double)
    case lockIn
}

/// A shared circular state indicator used across the distance-tracking
/// measurement phases (sphere, cylinder power, near add). Replaces the
/// previous green-checkmark gauge.
struct GuidanceCircleView: View {
    let state: GuidanceState
    /// Optional cm readout shown in the centre of the ring.
    let distanceCm: Float?
    var size: CGFloat = 110

    @State private var idlePulse: Bool = false
    @State private var snap: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor, lineWidth: 3)
                .opacity(backRingOpacity)

            if case .tracking(let progress) = state {
                Circle()
                    .trim(from: 0, to: progress.clamped01)
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            if let cm = distanceCm, cm > 0 {
                VStack(spacing: 0) {
                    Text("\(Int(cm))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("cm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scaleFactor)
        .animation(.easeInOut(duration: 0.25), value: state)
        .animation(.easeOut(duration: 0.18), value: snap)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        }
        .onChange(of: state) { oldState, newState in
            if newState == .lockIn && oldState != .lockIn {
                triggerSnap()
            }
        }
    }

    private var ringColor: Color {
        switch state {
        case .idle:      return .secondary
        case .listening: return .accentColor
        case .tracking:  return .secondary
        case .lockIn:    return .green
        }
    }

    private var backRingOpacity: Double {
        switch state {
        case .idle:      return idlePulse ? 0.7 : 0.3
        case .listening: return 0.85
        case .tracking:  return 0.25
        case .lockIn:    return 1.0
        }
    }

    private var scaleFactor: CGFloat {
        if snap { return 1.06 }
        switch state {
        case .idle:      return idlePulse ? 1.03 : 1.0
        case .listening: return 1.06
        case .tracking:  return 0.97
        case .lockIn:    return 1.0
        }
    }

    private func triggerSnap() {
        HapticFeedback.distanceLocked()
        snap = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            snap = false
        }
    }
}

private extension Double {
    var clamped01: Double { Swift.max(0, Swift.min(1, self)) }
}
