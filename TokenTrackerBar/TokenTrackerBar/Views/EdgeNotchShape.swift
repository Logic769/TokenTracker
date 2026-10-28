import SwiftUI

/// Right-edge "welded to the bezel" silhouette inspired by CodeNotch's
/// `SideNotchShape`, without cutout / dip / four-edge transforms.
///
/// Canonical layout: `rect.width` is depth into the screen, `rect.height` is
/// length along the edge, and `rect.maxX` is the physical screen edge. Top and
/// bottom ends flare back out to the bezel so the chrome reads as moulded into
/// the display rather than a floating capsule.
struct EdgeNotchShape: Shape {
    /// Ideal inverse curve length along the bezel (CodeNotch curl / fillet).
    /// On a thin resting pill the *depth* of this flare is scarce, but the
    /// along-edge run may still stretch into a gentle ellipse — see `path(in:)`.
    var curlRadius: CGFloat
    /// Convex corner on the inward (screen-facing) side.
    var cornerRadius: CGFloat
    /// Hairline of black pushed past the bezel so no wallpaper seam shows.
    var bezelHidden: CGFloat = 1
    /// Share of each bezel flare spent ramping curvature from zero
    /// (`fluidTurn`). 0.5 never holds a constant bend — softest bezel weld.
    var filletRamp: CGFloat = 0.5

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curlRadius, cornerRadius) }
        set {
            curlRadius = newValue.first
            cornerRadius = newValue.second
        }
    }

    /// Bézier handle reach for a circular quarter-turn (inward corners only).
    private static let circleReach: CGFloat = 0.5523

    func path(in rect: CGRect) -> Path {
        let depth = max(0, rect.width)
        let length = max(0, rect.height)
        guard depth > 0.5, length > 0.5 else { return Path(rect) }

        // Clamp order matches CodeNotch: corner first, then bezelHidden band,
        // then flare depth from what remains. A thin resting pill (~10 pt deep)
        // must keep round inward corners; squashing them behind curl collapses
        // the silhouette into a square tile.
        let corner = min(max(0, cornerRadius), depth / 2, length / 4)
        let hidden = min(max(0, bezelHidden), max(0, depth - corner - 0.5))
        let curlDepth = min(
            max(0, curlRadius),
            max(0, depth - corner - hidden)
        )
        // Along-edge run may exceed depth when depth is scarce. A circle of
        // radius curlDepth (~4 pt on the resting pill) looks stiff and poorly
        // welded; stretching the along axis ~3× into a gentle ellipse softens
        // the bezel join without eating the body. Cap at length/4 so a resting
        // 10×80 pill still reads as a pill, not two flares with no middle.
        let curlAlong = min(
            max(curlDepth, min(curlRadius, curlDepth * 3)),
            length / 4
        )

        let bodyTop = rect.minY + curlAlong
        let bodyBottom = rect.maxY - curlAlong
        let bezelX = rect.maxX
        let inwardX = rect.minX
        let ramp = min(max(filletRamp, 0), 0.5)

        var path = Path()
        // Top bezel tip.
        path.move(to: CGPoint(x: bezelX, y: rect.minY))
        if hidden > 0 {
            path.addLine(to: CGPoint(x: bezelX - hidden, y: rect.minY))
        }
        // Top flare: leave the bezel with zero curvature, arrive on the body.
        if curlAlong > 0.5, curlDepth > 0.5 {
            let flareEnd = CGPoint(x: bezelX - hidden - curlDepth, y: bodyTop)
            Self.fluidTurn(
                &path,
                to: flareEnd,
                leaving: CGVector(dx: 0, dy: 1),
                arriving: CGVector(dx: -1, dy: 0),
                ramp: ramp
            )
        } else if curlAlong > 0.5 {
            path.addLine(to: CGPoint(x: bezelX - hidden, y: bodyTop))
        }
        // Top inward corner — circular arc (circleReach), not fluidTurn.
        let topCornerStart = CGPoint(x: inwardX + corner, y: bodyTop)
        path.addLine(to: topCornerStart)
        if corner > 0.5 {
            path.addCurve(
                to: CGPoint(x: inwardX, y: bodyTop + corner),
                control1: CGPoint(
                    x: topCornerStart.x - corner * Self.circleReach,
                    y: topCornerStart.y
                ),
                control2: CGPoint(
                    x: inwardX,
                    y: bodyTop + corner - corner * Self.circleReach
                )
            )
        } else {
            path.addLine(to: CGPoint(x: inwardX, y: bodyTop))
        }
        // Inward straight edge.
        path.addLine(to: CGPoint(x: inwardX, y: bodyBottom - corner))
        // Bottom inward corner.
        if corner > 0.5 {
            path.addCurve(
                to: CGPoint(x: inwardX + corner, y: bodyBottom),
                control1: CGPoint(
                    x: inwardX,
                    y: bodyBottom - corner + corner * Self.circleReach
                ),
                control2: CGPoint(
                    x: inwardX + corner - corner * Self.circleReach,
                    y: bodyBottom
                )
            )
        } else {
            path.addLine(to: CGPoint(x: inwardX, y: bodyBottom))
        }
        // Bottom flare back out to the bezel.
        if curlAlong > 0.5, curlDepth > 0.5 {
            let flareStart = CGPoint(x: bezelX - hidden - curlDepth, y: bodyBottom)
            path.addLine(to: flareStart)
            let flareEnd = CGPoint(x: bezelX - hidden, y: rect.maxY)
            Self.fluidTurn(
                &path,
                to: flareEnd,
                leaving: CGVector(dx: 1, dy: 0),
                arriving: CGVector(dx: 0, dy: 1),
                ramp: ramp
            )
        } else {
            path.addLine(to: CGPoint(x: bezelX - hidden, y: bodyBottom))
            path.addLine(to: CGPoint(x: bezelX - hidden, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: bezelX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    /// A quarter turn whose bend ramps in from nothing at both ends.
    ///
    /// A single cubic arrives at the bezel at the right *angle* but with its
    /// whole bend already there — curvature jumps from zero along the border to
    /// full in one step, and the eye reads that as a stiff weld. Integrating
    /// curvature (CodeNotch `fluidTurn`) keeps the join soft.
    private static func fluidTurn(
        _ path: inout Path,
        to: CGPoint,
        leaving: CGVector,
        arriving: CGVector,
        ramp: CGFloat
    ) {
        guard let from = path.currentPoint else { return }
        let alongReach = (to.x - from.x) * leaving.dx + (to.y - from.y) * leaving.dy
        let acrossReach = (to.x - from.x) * arriving.dx + (to.y - from.y) * arriving.dy
        guard alongReach != 0, acrossReach != 0 else {
            path.addLine(to: to)
            return
        }
        let p = min(max(ramp, 0), 0.5)
        // Curvature × length so the turn lands on exactly a quarter circle.
        let bend = (CGFloat.pi / 2) / (1 - p)
        let steps = 64
        var heading: CGFloat = 0
        var u: CGFloat = 0
        var v: CGFloat = 0
        var walk: [(CGFloat, CGFloat)] = [(0, 0)]
        for i in 0..<steps {
            let s = (CGFloat(i) + 0.5) / CGFloat(steps)
            let share: CGFloat
            if p <= 0 {
                share = 1
            } else if s < p {
                share = s / p
            } else if s > 1 - p {
                share = (1 - s) / p
            } else {
                share = 1
            }
            heading += bend * share / CGFloat(steps)
            u += cos(heading) / CGFloat(steps)
            v += sin(heading) / CGFloat(steps)
            walk.append((u, v))
        }
        let (endU, endV) = walk[walk.count - 1]
        guard endU != 0, endV != 0 else {
            path.addLine(to: to)
            return
        }
        let alongScale = alongReach / endU
        let acrossScale = acrossReach / endV
        for (wu, wv) in walk.dropFirst() {
            path.addLine(to: CGPoint(
                x: from.x + leaving.dx * wu * alongScale + arriving.dx * wv * acrossScale,
                y: from.y + leaving.dy * wu * alongScale + arriving.dy * wv * acrossScale
            ))
        }
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
