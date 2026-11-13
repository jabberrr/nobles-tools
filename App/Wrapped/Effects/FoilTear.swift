import SwiftUI

/// The hole torn in the foil at some openness, from 0 (none) to 1 (only a rim left): its edge, and
/// the foil folded back around it.
///
/// The first third of the way tears a small hole a little up and right of the middle, its edge
/// jagged. The second widens it and folds its edge back: the torn edge rolls outward, leaving a
/// smoother crest around the hole and the jagged free edge further out. The last third widens it
/// to about the item's size, centered, so only a rim is left. Every size comes from the same
/// seeded points, so the hole tears wider rather than jumping.
struct FoilTear: Sendable {
    /// The hole's edge: the torn edge, or the fold's crest once it folds back.
    let crest: [CGPoint]
    /// The free edge of the foil folded back, the same as `crest` until it folds.
    let freeEdge: [CGPoint]
    /// Whether there's a hole yet.
    let isTorn: Bool

    init(openness: Double, geometry: FoilGeometry) {
        let radius = Double(geometry.radius)
        let size = radius * Self.ramp(openness, 0, 0.22, 0.42, 0.6)
        isTorn = size > 0
        let center = geometry.point(CGVector(
            dx: Self.ramp(openness, 0.15, 0.15, 0.06, 0.01),
            dy: Self.ramp(openness, -0.12, -0.12, -0.04, 0)
        ))
        let foldWidth = radius * Self.ramp(openness, 0, 0, 0.13, 0.09)
        let folded = min(max(Self.ramp(openness, 0, 0, 1, 1), 0), 1)
        // Teeth come in as the hole grows, so a hole just starting isn't a star.
        let teeth = radius > 0 ? 3.5 * Double(geometry.unit) * min(1, size / (0.35 * radius)) : 0
        var crest: [CGPoint] = []
        var freeEdge: [CGPoint] = []
        for notch in Self.notches {
            // The crest smooths out as the torn edge folds away from it.
            let reach = max(size * (1 + notch.wobble) + teeth * notch.tooth * (1 - 0.8 * folded), 0)
            let foldReach = max(reach + foldWidth * notch.foldWidth + 0.9 * teeth * notch.edgeTooth * folded, reach)
            crest.append(Self.point(from: center, toward: notch.direction, by: reach))
            freeEdge.append(Self.point(from: center, toward: notch.direction, by: foldReach))
        }
        self.crest = crest
        self.freeEdge = freeEdge
    }

    /// The hole, inside the crest.
    var hole: Path {
        isTorn ? Self.polygon(crest) : Path()
    }

    /// The hole and the foil folded back around it, out to the free edge.
    var fold: Path {
        isTorn ? Self.polygon(freeEdge) : Path()
    }

    /// Wrinkles across the folded band, from just off the crest to just short of the free edge.
    var foldCreases: Path {
        Path { path in
            for index in Self.notches.indices where Self.notches[index].hasCrease {
                let start = crest[index]
                let end = freeEdge[index]
                guard hypot(end.x - start.x, end.y - start.y) > 1 else { continue }
                path.move(to: Self.between(start, end, 0.15))
                path.addLine(to: Self.between(start, end, 0.9))
            }
        }
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points)
            path.closeSubpath()
        }
    }

    private static func point(from center: CGPoint, toward direction: CGVector, by distance: Double) -> CGPoint {
        let distance = CGFloat(distance)
        return CGPoint(x: center.x + direction.dx * distance, y: center.y + direction.dy * distance)
    }

    private static func between(_ a: CGPoint, _ b: CGPoint, _ fraction: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }

    /// The values at openness 0, ⅓, ⅔ and 1, joined by straight lines and carried on a little
    /// past 1, for a spring's overshoot.
    private static func ramp(_ openness: Double, _ values: Double...) -> Double {
        let position = min(max(openness, 0), 1.2) * 3
        let segment = min(Int(position), 2)
        let fraction = position - Double(segment)
        return values[segment] + (values[segment + 1] - values[segment]) * fraction
    }
}

// MARK: - The seeded edge

extension FoilTear {
    /// One of the points around the hole, the same at every size.
    private struct Notch: Sendable {
        /// Outward from the hole's middle, a little wider than tall.
        let direction: CGVector
        /// How far the hole bulges out or in here, as a fraction of its size.
        let wobble: Double
        /// How far the torn edge juts out (positive) or in, in teeth.
        let tooth: Double
        /// The same for the free edge of the fold.
        let edgeTooth: Double
        /// How wide the fold is here, as a fraction of its width.
        let foldWidth: Double
        /// Whether a wrinkle crosses the fold here.
        let hasCrease: Bool
    }

    private static let notches: [Notch] = {
        var random = SeededRandom(seed: 0x7EA2)
        let phases = (0..<3).map { _ in random.value(in: 0...(2 * .pi)) }
        let count = 40
        return (0..<count).map { index in
            let angle = (Double(index) + random.value(in: -0.3...0.3)) / Double(count) * 2 * .pi
            let tooth = random.value(in: -1...1)
            let edgeTooth = random.value(in: -1...1)
            let foldWidth = random.value(in: 0.75...1.25) * (1 + 0.25 * sin(3 * angle + phases[2]))
            return Notch(
                direction: CGVector(dx: cos(angle) * 1.04, dy: sin(angle) * 0.96),
                wobble: 0.07 * sin(2 * angle + phases[0]) + 0.04 * sin(3 * angle + phases[1]),
                tooth: tooth,
                edgeTooth: edgeTooth,
                foldWidth: foldWidth,
                hasCrease: index % 3 == 1
            )
        }
    }()
}

/// A part of the tear, filling the foil's stage, that tears wider as `openness` animates.
struct FoilTearShape: Shape {
    enum Part: Sendable {
        /// The hole, inside the crest.
        case hole
        /// The hole and the foil folded back around it.
        case fold
        /// The wrinkles across the fold.
        case foldCreases
    }

    var openness: Double
    let part: Part

    nonisolated var animatableData: Double {
        get { openness }
        set { openness = newValue }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let tear = FoilTear(openness: openness, geometry: FoilGeometry(size: rect.size))
        let path = switch part {
        case .hole: tear.hole
        case .fold: tear.fold
        case .foldCreases: tear.foldCreases
        }
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
