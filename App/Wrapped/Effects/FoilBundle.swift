import SwiftUI

/// The foil's outline: a puffy, lumpy bundle well bigger than the item and rounded off, so it hides
/// the item's shape, with pinches where the foil is gathered and creases running in from them.
/// Seeded, so it's the same on every run and in every snapshot.
///
/// Each bundle is the standard one, stretched just enough to cover the item's box with room to
/// spare: a little for an emoji, more for a big product photo. It stretches only partway toward
/// the item's proportions, so its outline gives nothing away.
struct FoilBundle: Sendable {
    let outline: Path
    let creases: Path

    init(geometry: FoilGeometry) {
        let corners = Self.lumps.map { lump in
            geometry.bundlePoint(Self.offset(lump.angle, reach: lump.reach))
        }
        outline = Self.curve(through: corners)
        creases = Path { path in
            for crease in Self.creaseLines {
                path.addLines(crease.map { geometry.bundlePoint(Self.offset($0)) })
            }
        }
    }

    /// How much bigger than the standard bundle one must be to cover `item` with `cover` to spare,
    /// across and down.
    static func scale(covering item: FoilItemBounds, on geometry: FoilGeometry) -> CGSize {
        let radius = Double(geometry.radius)
        guard radius > 0 else { return CGSize(width: 1, height: 1) }
        let cover = Double(Self.cover * geometry.unit)
        let halfWidth = Double(item.size.width) / 2 + cover
        let halfHeight = Double(item.size.height) / 2 + cover
        let corner = min(Double(item.cornerRadius) + cover, halfWidth, halfHeight)
        // Stretched only partway toward the item's proportions, so a can and a cookie get much
        // the same bundle.
        let stretch = pow(halfWidth / halfHeight, 0.35)
        // The outline comes no nearer its middle than `innerReach` of its half widths and heights,
        // so it covers the item once that inner ellipse takes in the item's grown box. The box's
        // rounded corners reach furthest.
        let farthest = (0...8).map { step in
            let angle = Double(step) / 8 * .pi / 2
            let x = halfWidth - corner + corner * cos(angle)
            let y = halfHeight - corner + corner * sin(angle)
            return hypot(x / stretch, y)
        }.max() ?? 0
        let needed = farthest / innerReach
        let standardWidth = Double(Self.extent.width) * radius
        let standardHeight = Double(Self.extent.height) * radius
        return CGSize(
            width: max(stretch * needed / standardWidth, 1),
            height: max(needed / standardHeight, 1)
        )
    }

    /// A smooth curve through the midpoints between corners, bending toward each lump and coming
    /// to a sharp point at each pinch.
    private static func curve(through corners: [CGPoint]) -> Path {
        guard let last = corners.last else { return Path() }
        var path = Path()
        path.move(to: midpoint(last, corners[0]))
        for index in corners.indices {
            let next = midpoint(corners[index], corners[(index + 1) % corners.count])
            if lumps[index].isPinch {
                path.addLine(to: corners[index])
                path.addLine(to: next)
            } else {
                path.addQuadCurve(to: next, control: corners[index])
            }
        }
        path.closeSubpath()
        return path
    }

    /// A point given in the bundle's half widths and heights from its middle, in radii of the
    /// standard bundle.
    private static func offset(_ angle: Double, reach: Double) -> CGVector {
        offset(CGVector(dx: cos(angle) * reach, dy: sin(angle) * reach))
    }

    private static func offset(_ unit: CGVector) -> CGVector {
        CGVector(dx: unit.dx * extent.width, dy: unit.dy * extent.height)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// MARK: - The seeded shape

extension FoilBundle {
    /// How far the foil stands off the item at the least, in points for a 220-point picture.
    private static let cover: CGFloat = 8

    /// The standard bundle's half width and half height, in `FoilGeometry.radius`.
    private static let extent = CGSize(width: 0.8, height: 0.77)

    /// A bulge of the outline, or a pinch between two.
    private struct Lump: Sendable {
        /// Radians, clockwise from the right.
        let angle: Double
        /// How far out it reaches, in the bundle's half widths and heights.
        let reach: Double
        let isPinch: Bool
    }

    private static let lumps: [Lump] = {
        var random = SeededRandom(seed: 0xF011)
        let count = 11
        let pinches: Set = [1, 5, 8]
        return (0..<count).map { index in
            let angle = (Double(index) + random.value(in: -0.2...0.2)) / Double(count) * 2 * .pi
            let isPinch = pinches.contains(index)
            let reach = isPinch ? random.value(in: 0.86...0.9) : random.value(in: 0.98...1.06)
            return Lump(angle: angle, reach: reach, isPinch: isPinch)
        }
    }()

    /// How near its middle the outline comes, in its half widths and heights. The outline runs
    /// through the midpoints between lumps, out from the chords between them and in to each
    /// pinch, so the nearest of those chords and pinch lines bounds it.
    private static let innerReach: Double = {
        let corners = lumps.map { CGPoint(x: cos($0.angle) * $0.reach, y: sin($0.angle) * $0.reach) }
        var chain: [CGPoint] = []
        for index in corners.indices {
            if lumps[index].isPinch {
                chain.append(corners[index])
            }
            chain.append(midpoint(corners[index], corners[(index + 1) % corners.count]))
        }
        return chain.indices.map { index in
            distanceFromOrigin(chain[index], chain[(index + 1) % chain.count])
        }.min() ?? 1
    }()

    /// How near the line from `a` to `b` comes to (0, 0).
    private static func distanceFromOrigin(_ a: CGPoint, _ b: CGPoint) -> Double {
        let run = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let length = run.dx * run.dx + run.dy * run.dy
        let along = length > 0 ? min(max(-(a.x * run.dx + a.y * run.dy) / length, 0), 1) : 0
        return Double(hypot(a.x + run.dx * along, a.y + run.dy * along))
    }

    /// Two creases fanning in from each pinch, each with a slight kink, in the bundle's half
    /// widths and heights from its middle.
    private static let creaseLines: [[CGVector]] = {
        var random = SeededRandom(seed: 0xC2EA5E5)
        return lumps.filter(\.isPinch).flatMap { pinch in
            [-1.0, 1.0].map { side in
                let turn = side * random.value(in: 0.15...0.45)
                let length = random.value(in: 0.25...0.42)
                let startX = cos(pinch.angle) * pinch.reach * 0.97
                let startY = sin(pinch.angle) * pinch.reach * 0.97
                let heading = pinch.angle + .pi + turn
                let kinkX = random.value(in: -0.04...0.04)
                let kinkY = random.value(in: -0.04...0.04)
                return [
                    CGVector(dx: startX, dy: startY),
                    CGVector(dx: startX + cos(heading) * length / 2 + kinkX, dy: startY + sin(heading) * length / 2 + kinkY),
                    CGVector(dx: startX + cos(heading) * length, dy: startY + sin(heading) * length),
                ]
            }
        }
    }()
}

/// The bundle's outline or its creases, filling the foil's stage.
struct FoilBundleShape: Shape {
    enum Part: Sendable {
        case outline, creases
    }

    let part: Part
    let item: FoilItemBounds

    nonisolated func path(in rect: CGRect) -> Path {
        let bundle = FoilBundle(geometry: FoilGeometry(size: rect.size, item: item))
        let path = part == .outline ? bundle.outline : bundle.creases
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
