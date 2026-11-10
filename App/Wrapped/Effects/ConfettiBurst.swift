import SwiftUI

/// A one-shot confetti burst filling its frame: fires each time `trigger` changes to a new value
/// above zero (bits of paper in `colors`, plus `emojis` if given), falls with gravity, fades out,
/// and stops redrawing after ~3 s. Never hit-testable. Draws nothing in static mode.
struct ConfettiBurst: View {
    static let defaultColors: [Color] = [
        Color(red: 1.00, green: 0.80, blue: 0.22),
        Color(red: 1.00, green: 0.42, blue: 0.56),
        Color(red: 0.38, green: 0.84, blue: 0.98),
        Color(red: 0.56, green: 0.94, blue: 0.62),
        Color(red: 0.76, green: 0.60, blue: 1.00),
        .white,
    ]

    private let trigger: Int
    private let colors: [Color]
    private let emojis: [String]

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shower: ConfettiShower?

    init(trigger: Int, colors: [Color] = ConfettiBurst.defaultColors, emojis: [String] = []) {
        self.trigger = trigger
        self.colors = colors
        self.emojis = emojis
    }

    var body: some View {
        Group {
            if !isStatic, let shower {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(shower.start)
                    Canvas { context, size in
                        shower.draw(in: context, size: size, elapsed: elapsed)
                    } symbols: {
                        ForEach(emojis.indices, id: \.self) { index in
                            Text(emojis[index])
                                .font(WrappedStyle.emoji(ConfettiShower.emojiSize))
                                .tag(index)
                        }
                    }
                }
            } else {
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            shower = ConfettiShower(
                seed: newValue,
                colors: colors.isEmpty ? Self.defaultColors : colors,
                emojiCount: emojis.count,
                isGentle: reduceMotion
            )
        }
        .task(id: shower?.start) {
            guard let lifetime = shower?.lifetime else { return }
            do {
                try await Task.sleep(for: .seconds(lifetime))
            } catch {
                return
            }
            shower = nil
        }
    }
}

/// One burst's pieces and how they move. Under Reduce Motion (`isGentle`) the pieces don't fly:
/// they fade in where they would have scattered to, then fade out.
struct ConfettiShower: Sendable {
    /// The point size emoji pieces are drawn at before scaling down.
    static let emojiSize: CGFloat = 40

    let start = Date.now
    /// Seconds until the last piece is gone.
    let lifetime: TimeInterval
    private let pieces: [Piece]
    private let isGentle: Bool

    init(seed: Int, colors: [Color], emojiCount: Int, isGentle: Bool) {
        var random = SeededRandom(seed, 0xC0FE)
        let papers = (0..<(isGentle ? 50 : 90)).map { _ in Piece.paper(colors: colors, using: &random) }
        let emojis = emojiCount > 0 ? (0..<14).map { _ in Piece.emoji(count: emojiCount, using: &random) } : []
        let pieces = papers + emojis
        self.pieces = pieces
        self.isGentle = isGentle
        lifetime = isGentle ? Self.gentleLifetime : (pieces.map(\.life).max() ?? 0)
    }

    func draw(in context: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let width = Double(size.width)
        let height = Double(size.height)
        for piece in pieces {
            let pose = isGentle
                ? piece.pose(at: Self.gentleScatterTime, width: width, height: height)
                : piece.pose(at: elapsed, width: width, height: height)
            let opacity = isGentle ? Self.gentleOpacity(at: elapsed) : pose.opacity
            guard opacity > 0.01 else { continue }

            var pieceContext = context
            pieceContext.opacity = opacity
            pieceContext.translateBy(x: CGFloat(pose.x), y: CGFloat(pose.y))
            pieceContext.rotate(by: .radians(pose.angle))
            switch piece.kind {
            case .strip, .dot:
                pieceContext.scaleBy(x: 1, y: CGFloat(pose.flip))
                let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                let path = piece.kind == .dot ? Path(ellipseIn: rect) : Path(rect)
                pieceContext.fill(path, with: .color(piece.color))
                if pose.flip < 0 {
                    pieceContext.fill(path, with: .color(.black.opacity(0.18)))
                }
            case .emoji(let index):
                pieceContext.scaleBy(x: CGFloat(piece.width), y: CGFloat(piece.width))
                if let symbol = pieceContext.resolveSymbol(id: index) {
                    pieceContext.draw(symbol, at: .zero)
                }
            }
        }
    }

    // MARK: Reduce Motion

    private static let gentleLifetime: TimeInterval = 1.4
    /// The moment of the flight a gentle burst shows, when the pieces are well spread out.
    private static let gentleScatterTime: TimeInterval = 0.9

    private static func gentleOpacity(at elapsed: TimeInterval) -> Double {
        let fadeIn = min(max(elapsed / 0.25, 0), 1)
        let fadeOut = min(max((gentleLifetime - elapsed) / 0.5, 0), 1)
        return min(fadeIn, fadeOut)
    }
}

private extension ConfettiShower {
    struct Piece: Sendable {
        enum Kind: Equatable, Sendable {
            case strip
            case dot
            /// The symbol tag of one of the emojis.
            case emoji(Int)
        }

        let kind: Kind
        let color: Color
        /// Paper size in points; for an emoji, `width` is its scale.
        let width: Double
        let height: Double
        /// Where it launches from (unit coordinates) and how fast, in shorter sides per second.
        let x: Double
        let y: Double
        let velocityX: Double
        let velocityY: Double
        /// Radians per second it turns, and how fast paper flips over.
        let spin: Double
        let flutter: Double
        let phase: Double
        /// Side-to-side drift in points.
        let sway: Double
        /// Seconds until it has faded out.
        let life: Double

        static func paper(colors: [Color], using random: inout SeededRandom) -> Piece {
            let isDot = random.value(in: 0...1) < 0.3
            let width = isDot ? random.value(in: 4.5...7) : random.value(in: 6...10)
            return launched(
                kind: isDot ? .dot : .strip,
                color: colors.randomElement(using: &random) ?? .white,
                width: width,
                height: isDot ? width : random.value(in: 3.5...5.5),
                speed: random.value(in: 0.9...2.1),
                spin: random.value(in: 2...7),
                life: random.value(in: 2.2...3.0),
                using: &random
            )
        }

        static func emoji(count: Int, using random: inout SeededRandom) -> Piece {
            launched(
                kind: .emoji(Int.random(in: 0..<count, using: &random)),
                color: .clear,
                width: random.value(in: 0.6...1),
                height: 0,
                speed: random.value(in: 0.8...1.6),
                spin: random.value(in: 1...3),
                life: random.value(in: 2.6...3.0),
                using: &random
            )
        }

        private static func launched(
            kind: Kind,
            color: Color,
            width: Double,
            height: Double,
            speed: Double,
            spin: Double,
            life: Double,
            using random: inout SeededRandom
        ) -> Piece {
            let angle = -Double.pi / 2 + random.value(in: -1.25...1.25)
            return Piece(
                kind: kind,
                color: color,
                width: width,
                height: height,
                x: 0.5 + random.value(in: -0.06...0.06),
                y: 0.42 + random.value(in: -0.04...0.04),
                velocityX: cos(angle) * speed,
                velocityY: sin(angle) * speed,
                spin: spin * random.sign(),
                flutter: random.value(in: 5...11),
                phase: random.value(in: 0...(2 * Double.pi)),
                sway: random.value(in: 6...16),
                life: life
            )
        }

        struct Pose {
            var x: Double
            var y: Double
            var angle: Double
            /// The paper's vertical scale as it flips over: negative shows its back.
            var flip: Double
            var opacity: Double
        }

        /// Where it is `time` seconds into its flight: launched fast, slowed by air, then falling
        /// at a steady speed with a gentle sway (exact motion under linear drag).
        func pose(at time: Double, width frameWidth: Double, height frameHeight: Double) -> Pose {
            let time = max(time, 0)
            let drag = 2.4
            let fallSpeed = 0.3 * frameHeight
            let side = min(frameWidth, frameHeight)
            let slowed = (1 - exp(-drag * time)) / drag
            let flip = cos(flutter * time + phase)
            return Pose(
                x: x * frameWidth + velocityX * side * slowed + sway * sin(flutter * 0.35 * time + phase) * min(time, 1),
                y: y * frameHeight + (velocityY * side - fallSpeed) * slowed + fallSpeed * time,
                angle: phase + spin * time,
                flip: flip < 0 ? min(flip, -0.08) : max(flip, 0.08),
                opacity: min(max((life - time) / 0.6, 0), 1)
            )
        }
    }
}

private struct ConfettiBurstPreview: View {
    @State private var trigger = 0

    var body: some View {
        ZStack {
            Color.indigo.ignoresSafeArea()
            Button("Celebrate") { trigger += 1 }
                .buttonStyle(.borderedProminent)
            ConfettiBurst(trigger: trigger, emojis: ["🧋", "🥯"])
                .ignoresSafeArea()
        }
    }
}

#Preview("Confetti") {
    ConfettiBurstPreview()
}
