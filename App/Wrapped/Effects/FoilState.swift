import SwiftUI

/// Which facets of a `FoilSheet` are still on, and the pieces flying off. Each tap tears off the
/// facets nearest to it, in chunks that grow (one share, then two, then three…) so the last tap
/// takes whatever is left.
struct FoilState: Sendable {
    let tapsToUnwrap: Int
    private(set) var taps = 0
    /// Per facet of the sheet, whether it's still on.
    private(set) var isAttached: [Bool]
    private(set) var pieces: [FoilPiece] = []
    /// When the latest tap landed (seconds since the reference date), for the shake.
    private(set) var lastTapTime: TimeInterval?

    /// The foil with `initialTaps` already torn off at fixed points, with nothing in flight.
    init(sheet: FoilSheet, tapsToUnwrap: Int, initialTaps: Int) {
        self.tapsToUnwrap = max(tapsToUnwrap, 1)
        isAttached = Array(repeating: true, count: sheet.facets.count)
        while taps < min(initialTaps, self.tapsToUnwrap) {
            tear(sheet, at: nextPresetPoint)
        }
    }

    var isUnwrapped: Bool {
        taps >= tapsToUnwrap
    }

    /// Where the next tap lands when no one chose a spot (`initialTaps`, VoiceOver): spread out
    /// so a part-unwrapped foil shows a bit of the middle.
    var nextPresetPoint: CGPoint {
        Self.presetPoints[taps % Self.presetPoints.count]
    }

    /// Tears off the next chunk around `point` (unit coordinates) at `time`, sending it flying.
    mutating func tap(_ sheet: FoilSheet, at point: CGPoint, time: TimeInterval) {
        guard !isUnwrapped else { return }
        let torn = tear(sheet, at: point)
        let tapCount = taps
        let isBurst = isUnwrapped
        let flying = torn.map { index in
            FoilPiece(facet: sheet.facets[index], index: index, tap: point, taps: tapCount, time: time, isBurst: isBurst)
        }
        pieces += flying
        lastTapTime = time
    }

    /// Forgets the pieces that have finished flying by `time`.
    mutating func dropLandedPieces(at time: TimeInterval) {
        pieces.removeAll { $0.end <= time }
    }

    /// Counts a tap and detaches the facets it tears off, nearest first; returns their indices.
    @discardableResult
    private mutating func tear(_ sheet: FoilSheet, at point: CGPoint) -> [Int] {
        taps += 1
        let attached = isAttached.indices.filter { isAttached[$0] }
        let left = isUnwrapped ? 0 : Self.facetsLeft(afterTap: taps, of: tapsToUnwrap, facets: sheet.facets.count)
        let count = isUnwrapped ? attached.count : min(max(attached.count - left, 1), attached.count)
        let torn = attached
            .map { (index: $0, reach: sheet.facets[$0].reach(from: point)) }
            .sorted { $0.reach < $1.reach }
            .prefix(count)
            .map { $0.index }
        for index in torn {
            isAttached[index] = false
        }
        return torn
    }

    /// How many of `facets` are left after tap number `tap` of `total`.
    private static func facetsLeft(afterTap tap: Int, of total: Int, facets: Int) -> Int {
        let tornShare = Double(tap * (tap + 1)) / Double(total * (total + 1))
        return facets - Int((Double(facets) * tornShare).rounded())
    }

    private static let presetPoints = [
        CGPoint(x: 0.70, y: 0.30),
        CGPoint(x: 0.26, y: 0.46),
        CGPoint(x: 0.60, y: 0.76),
        CGPoint(x: 0.34, y: 0.24),
        CGPoint(x: 0.74, y: 0.64),
        CGPoint(x: 0.50, y: 0.50),
    ]
}

/// A facet that has torn off, flying away from the tap that tore it.
struct FoilPiece: Sendable {
    /// The longest a piece can take to land, counted from its tap, in seconds.
    static let longestFlight: TimeInterval = 1.7

    /// Its index in the sheet.
    let facet: Int
    /// The tap that tore it (unit coordinates), and how many taps there had been, which set its
    /// crinkle.
    let tap: CGPoint
    let taps: Int
    /// When it lets go (nearest pieces first) and how long it flies.
    let start: TimeInterval
    let duration: TimeInterval
    /// Whether the final tap blew it off with the rest: it flies faster and farther.
    let isBurst: Bool

    var end: TimeInterval {
        start + duration
    }

    init(facet: FoilFacet, index: Int, tap: CGPoint, taps: Int, time: TimeInterval, isBurst: Bool) {
        var random = SeededRandom(seed: facet.seed)
        let stagger = isBurst
            ? random.value(in: 0...0.08)
            : min(facet.reach(from: tap) * 0.35, 0.14) + random.value(in: 0...0.04)
        self.facet = index
        self.tap = tap
        self.taps = taps
        self.isBurst = isBurst
        start = time + stagger
        duration = isBurst ? random.value(in: 1.0...1.4) : random.value(in: 0.95...1.25)
    }
}
