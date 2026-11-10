import SwiftUI

/// A sheet of crinkled foil: a jittered grid whose cells split into two triangles along a random
/// diagonal, each facet leaning its own way so it catches the light on its own. Coordinates are
/// unit (0...1 across the foil's frame), so one sheet fits any size.
struct FoilSheet: Sendable {
    /// The sheet every `FoilWrap` uses: 7 × 7 cells, 98 facets.
    static let standard = FoilSheet(columns: 7, rows: 7, seed: 0xF011)
    /// How far the foil reaches past the wrapped content on each side, in points.
    static let overhang: CGFloat = 14

    let facets: [FoilFacet]

    init(columns: Int, rows: Int, seed: UInt64) {
        var random = SeededRandom(seed: seed)
        var grid: [[CGPoint]] = []
        for row in 0...rows {
            var line: [CGPoint] = []
            for column in 0...columns {
                line.append(Self.vertex(column: column, row: row, columns: columns, rows: rows, using: &random))
            }
            grid.append(line)
        }

        var facets: [FoilFacet] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let topLeft = grid[row][column]
                let topRight = grid[row][column + 1]
                let bottomLeft = grid[row + 1][column]
                let bottomRight = grid[row + 1][column + 1]
                let triangles = Bool.random(using: &random)
                    ? [(topLeft, topRight, bottomRight), (topLeft, bottomRight, bottomLeft)]
                    : [(topLeft, topRight, bottomLeft), (topRight, bottomRight, bottomLeft)]
                for (a, b, c) in triangles {
                    facets.append(FoilFacet(a: a, b: b, c: c, using: &random))
                }
            }
        }
        self.facets = facets
    }

    /// A grid point: inner points wander up to a third of a cell; edge points only slide along
    /// their edge (corners stay put), then bulge or dip a little for a ragged outline.
    private static func vertex(
        column: Int,
        row: Int,
        columns: Int,
        rows: Int,
        using random: inout SeededRandom
    ) -> CGPoint {
        let isSideEdge = column == 0 || column == columns
        let isTopOrBottomEdge = row == 0 || row == rows
        var x = Double(column) / Double(columns)
        var y = Double(row) / Double(rows)
        if !isSideEdge {
            x += random.value(in: -0.34...0.34) / Double(columns)
        }
        if !isTopOrBottomEdge {
            y += random.value(in: -0.34...0.34) / Double(rows)
        }
        let point = rounded(x: x, y: y)
        guard isSideEdge || isTopOrBottomEdge else { return point }
        let crinkle = 1 + random.value(in: -0.012...0.008)
        return CGPoint(x: 0.5 + (point.x - 0.5) * crinkle, y: 0.5 + (point.y - 0.5) * crinkle)
    }

    /// Pulls a point of the unit square partway toward the inscribed circle, so the sheet has
    /// softly rounded corners, like foil pressed around something, while still covering the
    /// content's corners.
    private static func rounded(x: Double, y: Double) -> CGPoint {
        let roundness = 0.22
        let u = 2 * x - 1
        let v = 2 * y - 1
        let circleU = u * (1 - v * v / 2).squareRoot()
        let circleV = v * (1 - u * u / 2).squareRoot()
        return CGPoint(
            x: (u + (circleU - u) * roundness + 1) / 2,
            y: (v + (circleV - v) * roundness + 1) / 2
        )
    }
}

/// One triangle of the foil sheet, in unit coordinates.
struct FoilFacet: Sendable {
    let a: CGPoint
    let b: CGPoint
    let c: CGPoint
    let center: CGPoint
    /// Which way the crinkle leans before any tap (radians), and how steeply (0...1).
    let restingLean: Double
    let steepness: Double
    /// How brightly it flashes as the highlight sweeps past.
    let glint: Double
    /// Its spot on the iridescent color cycle (0...1), and how much of that color shows.
    let hue: Double
    let iridescence: Double
    /// Scales its distance from a tap, so torn edges come out ragged.
    let raggedness: Double
    /// Seeds its re-crinkling and its flight.
    let seed: UInt64

    init(a: CGPoint, b: CGPoint, c: CGPoint, using random: inout SeededRandom) {
        self.a = a
        self.b = b
        self.c = c
        center = CGPoint(x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3)
        restingLean = random.value(in: 0...(2 * Double.pi))
        steepness = random.value(in: 0.3...1)
        glint = random.value(in: 0.35...1)
        hue = random.value(in: 0...1)
        iridescence = random.value(in: 0...1) < 0.45 ? random.value(in: 0.08...0.24) : 0.03
        raggedness = random.value(in: 0.72...1.32)
        seed = random.next()
    }

    /// Which way it leans after `taps` taps: each tap crumples the foil a little differently.
    func lean(afterTaps taps: Int) -> Double {
        guard taps > 0 else { return restingLean }
        var random = SeededRandom(Int(truncatingIfNeeded: seed), taps)
        return restingLean + random.value(in: -0.9...0.9)
    }

    /// How far a tap at `point` is, for choosing what it tears off.
    func reach(from point: CGPoint) -> Double {
        hypot(Double(center.x - point.x), Double(center.y - point.y)) * raggedness
    }

    /// The triangle in a frame of `size`, in points.
    func path(in size: CGSize) -> Path {
        var path = Path()
        path.move(to: Self.scaled(a, to: size))
        path.addLine(to: Self.scaled(b, to: size))
        path.addLine(to: Self.scaled(c, to: size))
        path.closeSubpath()
        return path
    }

    /// The triangle in points, around its own center (for drawing it in flight).
    func centeredPath(in size: CGSize) -> Path {
        let middle = center(in: size)
        return path(in: size).offsetBy(dx: -middle.x, dy: -middle.y)
    }

    func center(in size: CGSize) -> CGPoint {
        Self.scaled(center, to: size)
    }

    /// The distance from its center to its farthest corner, in points.
    func radius(in size: CGSize) -> Double {
        let middle = center(in: size)
        func distance(to corner: CGPoint) -> Double {
            let point = Self.scaled(corner, to: size)
            return hypot(Double(point.x - middle.x), Double(point.y - middle.y))
        }
        return max(distance(to: a), distance(to: b), distance(to: c))
    }

    private static func scaled(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
