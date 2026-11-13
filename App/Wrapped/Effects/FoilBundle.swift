import SwiftUI

/// The foil's outline: a puffy, lumpy bundle well bigger than the item and rounded off, so it hides
/// the item's shape, with pinches where the foil is gathered and creases running in from them.
/// Seeded, so it's the same on every run and in every snapshot.
struct FoilBundle: Sendable {
    /// How far the foil stands off the item at the least, in points for a 220-point picture: the
    /// bundle also takes in the item's silhouette grown this much, so no part of a big item pokes
    /// out of it.
    static let cover: CGFloat = 10

    /// The bundle's half width and half height, in radii of the stage.
    private static let extent = CGSize(width: 0.8, height: 0.77)

    let outline: Path
    let creases: Path

    init(geometry: FoilGeometry) {
        let corners = Self.lumps.map { lump in
            Self.point(lump.angle, reach: lump.reach, geometry: geometry)
        }
        outline = Self.outline(through: corners)
        creases = Path { path in
            for crease in Self.creases {
                path.addLines(crease.map { Self.point($0, geometry: geometry) })
            }
        }
    }

    /// A smooth curve through the midpoints between corners, bending toward each lump and coming
    /// to a sharp point at each pinch.
    private static func outline(through corners: [CGPoint]) -> Path {
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

    private static func point(_ angle: Double, reach: Double, geometry: FoilGeometry) -> CGPoint {
        point(CGVector(dx: cos(angle) * reach, dy: sin(angle) * reach), geometry: geometry)
    }

    /// A point given in the bundle's own half widths and heights from its middle.
    private static func point(_ offset: CGVector, geometry: FoilGeometry) -> CGPoint {
        geometry.point(CGVector(dx: offset.dx * Self.extent.width, dy: offset.dy * Self.extent.height))
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// MARK: - The seeded shape

extension FoilBundle {
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

    /// Two creases fanning in from each pinch, each with a slight kink, in the bundle's half
    /// widths and heights from its middle.
    private static let creases: [[CGVector]] = {
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

    nonisolated func path(in rect: CGRect) -> Path {
        let bundle = FoilBundle(geometry: FoilGeometry(size: rect.size))
        let path = part == .outline ? bundle.outline : bundle.creases
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
