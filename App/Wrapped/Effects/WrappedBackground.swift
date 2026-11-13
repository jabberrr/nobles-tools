import SwiftUI

/// The story's backdrop: a slow swirl of `colors` (2–4). A gradient of them turns under soft
/// pools of the same colors and of shade, which circle the middle of the screen at their own
/// speeds, so the colors keep flowing through each other. Changing `colors` cross-fades. Fills
/// its frame; callers add `.ignoresSafeArea()`. One still frame in static mode and under Reduce
/// Motion.
///
/// It only ever draws `colors` and darker shades of them, so text that contrasts with every one
/// of them stays readable.
struct WrappedBackground: View {
    private let colors: [Color]

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The palettes on screen, bottom first: the newest fades in over the ones it replaces.
    @State private var layers: [Layer]

    init(colors: [Color]) {
        self.colors = colors
        _layers = State(initialValue: [Layer(id: 0, colors: colors)])
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
        .accessibilityHidden(true)
        .onChange(of: colors) { _, newColors in
            let layer = Layer(id: (layers.last?.id ?? 0) + 1, colors: newColors)
            withAnimation(.easeInOut(duration: 0.8)) { layers.append(layer) }
        }
        .task(id: layers.last?.id) {
            guard layers.count > 1 else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            layers.removeFirst(layers.count - 1)
        }
    }

    private func field(at time: TimeInterval) -> some View {
        ZStack {
            ForEach(layers) { layer in
                SwirlField(colors: layer.colors, time: time)
                    .transition(.opacity)
            }
        }
    }

    private struct Layer: Identifiable {
        let id: Int
        let colors: [Color]
    }
}

/// One palette's swirl, at one moment.
private struct SwirlField: View {
    let colors: [Color]
    let time: TimeInterval

    var body: some View {
        let painter = SwirlPainter(colors: colors, time: time)
        Canvas { context, size in
            painter.draw(in: &context, size: size)
        }
    }
}

/// Draws a turning base gradient, then soft pools of color and shade circling a slowly
/// wandering middle. Time 0 is the still frame.
private struct SwirlPainter: Sendable {
    let colors: [Color]
    let time: TimeInterval

    /// The base gradient's direction at time 0, in radians, and how fast it turns, in radians a
    /// second.
    private static let baseAngle = 0.9
    private static let baseSpeed = 0.05

    /// A pool circling the swirl's middle. Its orbit reaches `orbit` of the frame's width across
    /// and nearly as much of its height down, so it sweeps a tall screen top to bottom.
    private struct Pool: Sendable {
        enum Paint: Sendable {
            /// The palette color this many from the end.
            case color(fromEnd: Int)
            case shade
        }

        let paint: Paint
        let orbit: Double
        /// Radians a second, all the same way round.
        let speed: Double
        /// Where on its orbit it is at time 0, in radians.
        let phase: Double
        /// Its radius, as a share of the frame's longer side.
        let size: Double
        let opacity: Double
    }

    /// Outer pools turn slower than inner ones, so the colors twist as they go round. Colors
    /// first, then shade over them.
    private static let pools = [
        Pool(paint: .color(fromEnd: 0), orbit: 0.34, speed: 0.13, phase: 0.6, size: 0.48, opacity: 0.9),
        Pool(paint: .color(fromEnd: 1), orbit: 0.30, speed: 0.16, phase: 2.7, size: 0.42, opacity: 0.85),
        Pool(paint: .color(fromEnd: 2), orbit: 0.40, speed: 0.10, phase: 4.6, size: 0.50, opacity: 0.85),
        Pool(paint: .color(fromEnd: 1), orbit: 0.14, speed: 0.21, phase: 1.6, size: 0.34, opacity: 0.7),
        Pool(paint: .shade, orbit: 0.36, speed: 0.09, phase: 3.6, size: 0.50, opacity: 0.2),
        Pool(paint: .shade, orbit: 0.24, speed: 0.14, phase: 0.2, size: 0.40, opacity: 0.16),
    ]

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let palette = Self.palette(colors)
        let width = Double(size.width)
        let height = Double(size.height)

        let angle = Self.baseAngle + Self.baseSpeed * time
        let reach = hypot(width, height) / 2
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: palette),
                startPoint: CGPoint(x: width / 2 - cos(angle) * reach, y: height / 2 - sin(angle) * reach),
                endPoint: CGPoint(x: width / 2 + cos(angle) * reach, y: height / 2 + sin(angle) * reach)
            )
        )

        let middleX = 0.5 + 0.06 * sin(0.05 * time)
        let middleY = 0.48 + 0.05 * cos(0.07 * time)
        let longest = max(width, height)
        for pool in Self.pools {
            let color = switch pool.paint {
            case .color(let fromEnd): palette[palette.count - 1 - fromEnd % palette.count]
            case .shade: Color.black
            }
            let turn = pool.phase + pool.speed * time
            let x = (middleX + pool.orbit * cos(turn)) * width
            let y = (middleY + pool.orbit * 0.9 * sin(turn)) * height
            let radius = pool.size * longest
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: color.opacity(pool.opacity), location: 0),
                        .init(color: color.opacity(pool.opacity * 0.45), location: 0.5),
                        .init(color: color.opacity(0), location: 1),
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: CGFloat(radius)
                )
            )
        }
    }

    /// At least two colors to draw with.
    private static func palette(_ colors: [Color]) -> [Color] {
        switch colors.count {
        case 0: [Color(white: 0.12), Color(white: 0.2)]
        case 1: [colors[0], colors[0]]
        default: colors
        }
    }
}

/// Tap to step through every page's colors.
private struct WrappedBackgroundPreview: View {
    @State private var page = WrappedPage.intro

    var body: some View {
        WrappedBackground(colors: page.colors)
            .ignoresSafeArea()
            .onTapGesture {
                page = WrappedPage(rawValue: (page.rawValue + 1) % WrappedPage.allCases.count) ?? .intro
            }
            .overlay {
                Text("Tap to change colors").font(WrappedStyle.lead).foregroundStyle(.white)
            }
    }
}

#Preview("Background") {
    WrappedBackgroundPreview()
}
