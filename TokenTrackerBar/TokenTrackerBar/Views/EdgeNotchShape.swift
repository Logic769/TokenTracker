import SwiftUI

/// Right-edge flush silhouette: a rounded rect welded square into the bezel.
///
/// Canonical layout: `rect.width` is depth into the screen, `rect.height` is
/// length along the edge, and `rect.maxX` is the physical screen edge. Top and
/// bottom run straight into the bezel at 90°; only the inward (left) corners
/// are rounded. No concave bezel flares / ears.
struct EdgeNotchShape: Shape {
    /// Convex corner on the inward (screen-facing) side.
    var cornerRadius: CGFloat
    /// Hairline of black pushed *past* the bezel so no wallpaper seam shows.
    /// Does not extend the visible body along the edge (no ears).
    var bezelHidden: CGFloat = 1

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    /// Bézier handle reach for a circular quarter-turn (inward corners only).
    private static let circleReach: CGFloat = 0.5523

    func path(in rect: CGRect) -> Path {
        let depth = max(0, rect.width)
        let length = max(0, rect.height)
        guard depth > 0.5, length > 0.5 else { return Path(rect) }

        let corner = min(max(0, cornerRadius), depth / 2, length / 4)
        let hidden = max(0, bezelHidden)
        // Bezel is the right edge of the shape; optional hairline past it.
        let bezelX = rect.maxX
        let outerX = bezelX + hidden
        let inwardX = rect.minX
        let topY = rect.minY
        let bottomY = rect.maxY

        var path = Path()
        // Top-right: start past the bezel (hidden) or on it, then flush left.
        path.move(to: CGPoint(x: outerX, y: topY))
        // Top edge runs straight into the bezel — square join, no crook.
        path.addLine(to: CGPoint(x: inwardX + corner, y: topY))
        // Top inward corner — circular arc.
        if corner > 0.5 {
            path.addCurve(
                to: CGPoint(x: inwardX, y: topY + corner),
                control1: CGPoint(
                    x: inwardX + corner - corner * Self.circleReach,
                    y: topY
                ),
                control2: CGPoint(
                    x: inwardX,
                    y: topY + corner - corner * Self.circleReach
                )
            )
        } else {
            path.addLine(to: CGPoint(x: inwardX, y: topY))
        }
        // Inward straight edge.
        path.addLine(to: CGPoint(x: inwardX, y: bottomY - corner))
        // Bottom inward corner.
        if corner > 0.5 {
            path.addCurve(
                to: CGPoint(x: inwardX + corner, y: bottomY),
                control1: CGPoint(
                    x: inwardX,
                    y: bottomY - corner + corner * Self.circleReach
                ),
                control2: CGPoint(
                    x: inwardX + corner - corner * Self.circleReach,
                    y: bottomY
                )
            )
        } else {
            path.addLine(to: CGPoint(x: inwardX, y: bottomY))
        }
        // Bottom edge straight to (and past) the bezel — square join.
        path.addLine(to: CGPoint(x: outerX, y: bottomY))
        path.closeSubpath()
        return path
    }
}

/// Motion vocabulary for the right-edge surface — mirrors CodeNotch's
/// `NotchMotion` so expand/collapse feels like liquid chrome, not a hard cut.
enum EdgeNotchMotion {
    /// Folding open and shut (CodeNotch `unfold`: 0.62 / 0.72).
    static let unfold = Animation.spring(response: 0.62, dampingFraction: 0.72)
    /// Contents catching up with the black shape.
    static let contents = Animation.spring(response: 0.48, dampingFraction: 0.80)
    /// Brief wake deepen on approach before full expand.
    static let wake = Animation.spring(response: 0.28, dampingFraction: 0.78)

    static func respectingReduceMotion(_ animation: Animation, reduce: Bool) -> Animation? {
        reduce ? nil : animation
    }
}
