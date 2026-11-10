import SwiftUI

/// Emoji drifting slowly upward with a gentle sway across its frame (`count` at a time), for the
/// intro. Never hit-testable. A fixed, deterministic scatter in static mode (and under Reduce Motion).
struct FloatingEmoji: View {
    private let emojis: [String]
    private let drifters: [Drifter]

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ emojis: [String], count: Int = 16) {
        self.emojis = emojis
        let count = emojis.isEmpty ? 0 : max(count, 0)
        // Shuffled lanes, so the emoji starting lower aren't also the ones further left.
        var random = SeededRandom(seed: 0x1A7E5)
        let lanes = Array(0..<count).shuffled(using: &random)
        drifters = lanes.indices.map { Drifter(index: $0, lane: lanes[$0], count: count) }
    }

    var body: some View {
        Group {
            if isStatic || reduceMotion {
                field(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    field(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func field(at time: TimeInterval) -> some View {
        GeometryReader { proxy in
            ForEach(drifters) { drifter in
                let pose = drifter.pose(at: time, in: proxy.size)
                Text(emojis[(drifter.id + pose.cycle) % emojis.count])
                    .font(WrappedStyle.number(drifter.size))
                    .rotationEffect(.degrees(pose.angle))
                    .opacity(pose.opacity)
                    .position(pose.point)
            }
        }
    }
}

/// One emoji's path: it rises from below the frame to above it, then starts again from a new
/// spot in its lane.
private struct Drifter: Identifiable {
    let id: Int
    let size: CGFloat
    /// Seconds to cross the frame, and how far through the first crossing it starts.
    private let duration: Double
    private let offset: Double
    /// Where its strip of the width starts, and the strip's width, so emoji spread out.
    private let laneStart: Double
    private let laneWidth: Double
    private let sway: Double
    private let swaySpeed: Double
    /// Nearer (bigger) emoji are more opaque, for a little depth.
    private let depth: Double

    init(index: Int, lane: Int, count: Int) {
        var random = SeededRandom(index, 0xF10A7)
        let laneWidth = 1 / Double(max(count, 1))
        let depth = random.value(in: 0...1)
        id = index
        self.depth = depth
        self.laneWidth = laneWidth
        size = CGFloat(24 + 22 * depth)
        duration = random.value(in: 11...19)
        offset = (Double(index) + random.value(in: 0...0.8)) * laneWidth
        laneStart = Double(lane) * laneWidth
        sway = random.value(in: 8...22)
        swaySpeed = random.value(in: 0.4...0.9)
    }

    struct Pose {
        var point: CGPoint
        var angle: Double
        var opacity: Double
        /// How many times it has crossed, to vary its emoji and its spot each time.
        var cycle: Int
    }

    func pose(at time: TimeInterval, in frame: CGSize) -> Pose {
        let width = Double(frame.width)
        let height = Double(frame.height)
        let travel = time / duration + offset
        let cycle = Int(travel.rounded(.down))
        let progress = travel - Double(cycle)
        var random = SeededRandom(id, cycle)
        let lanePosition = laneStart + laneWidth * random.value(in: 0.15...0.85)
        let margin = Double(size)
        let swing = sin(time * swaySpeed + Double(id))
        let edgeFade = min(progress / 0.15, (1 - progress) / 0.15, 1)
        return Pose(
            point: CGPoint(
                x: (lanePosition * 0.9 + 0.05) * width + sway * swing,
                y: height + margin - (height + 2 * margin) * progress
            ),
            angle: 10 * swing,
            opacity: max(edgeFade, 0) * (0.45 + 0.45 * depth),
            cycle: cycle
        )
    }
}

#Preview("Floating emoji") {
    FloatingEmoji(["🧋", "🥯", "🍪", "🥪", "🍵"])
        .background(Color(red: 0.2, green: 0.1, blue: 0.4))
        .ignoresSafeArea()
}
