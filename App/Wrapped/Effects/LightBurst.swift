import SwiftUI

/// Light bursting from behind something `size` big as it's revealed. When `isLit` turns true, a
/// flash and a fan of rays flare out, then settle into a soft glow with faint, slowly turning
/// rays, and sparkles pop in around it. Drawn settled in static mode; under Reduce Motion it
/// fades in, with no flare and no turning. Never hit-testable.
struct LightBurst: View {
    let isLit: Bool
    /// The size of what it's behind.
    let size: CGSize
    var color: Color = WrappedStyle.highlight

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isLit = isStatic || self.isLit
        let reach = max(size.width, size.height) * 1.5
        ZStack {
            glow(isLit)
            rays(isLit, diameter: reach)
            if !isStatic && !reduceMotion {
                flash(diameter: reach)
            }
            sparkles(isLit)
        }
        .frame(width: reach, height: reach)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glow(_ isLit: Bool) -> some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(color)
            .frame(width: size.width + 24, height: size.height + 24)
            .blur(radius: 28)
            .opacity(isLit ? 0.4 : 0)
            .animation(.easeOut(duration: 0.8), value: isLit)
    }

    /// The fan of rays: flung out on the reveal, then turning slowly while it's lit. One timeline
    /// holds the fan whether it turns or not, so the fling animates. The turn is slow enough that
    /// ten frames a second look smooth.
    @ViewBuilder
    private func rays(_ isLit: Bool, diameter: CGFloat) -> some View {
        let fan = rayFan(diameter: diameter)
            .scaleEffect(isLit || reduceMotion ? 1 : 0.4)
            .opacity(isLit ? 0.55 : 0)
            .animation(raysAnimation, value: isLit)
        if isStatic || reduceMotion {
            fan
        } else {
            TimelineView(.animation(minimumInterval: 0.1, paused: !isLit)) { timeline in
                // Two degrees a second: a full turn every three minutes.
                let seconds = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 180)
                fan.rotationEffect(.degrees(isLit ? seconds * 2 : 0))
            }
        }
    }

    private var raysAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.4) : .spring(duration: 0.7, bounce: 0.25)
    }

    private func rayFan(diameter: CGFloat) -> some View {
        Self.rayPath(count: 16, diameter: diameter)
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: color.opacity(0), location: 0.2),
                        .init(color: color.opacity(0.65), location: 0.42),
                        .init(color: color.opacity(0), location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }

    /// A white flare from the middle as the light bursts.
    private func flash(diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: diameter * 0.35))
            .frame(width: diameter * 0.7, height: diameter * 0.7)
            .keyframeAnimator(initialValue: Flare(), trigger: isLit) { flare, value in
                flare
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.3, duration: 0.5)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.9, duration: 0.1)
                    LinearKeyframe(0, duration: 0.6, timingCurve: .easeOut)
                }
            }
    }

    private func sparkles(_ isLit: Bool) -> some View {
        ZStack {
            ForEach(Sparkle.all.indices, id: \.self) { index in
                let sparkle = Sparkle.all[index]
                Image(systemName: "sparkle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: sparkle.size, height: sparkle.size)
                    .foregroundStyle(index.isMultiple(of: 2) ? color : .white)
                    .scaleEffect(isLit || reduceMotion ? 1 : 0.1)
                    .opacity(isLit ? 1 : 0)
                    .animation(sparkleAnimation(index), value: isLit)
                    .offset(x: sparkle.x * size.width / 2, y: sparkle.y * size.height / 2)
            }
        }
    }

    private func sparkleAnimation(_ index: Int) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.4)
            : .spring(duration: 0.5, bounce: 0.6).delay(0.1 + 0.08 * Double(index))
    }

    /// Thin wedges fanning out from the middle of a `diameter`-sized square.
    private static func rayPath(count: Int, diameter: CGFloat) -> Path {
        let radius = Double(diameter) / 2
        let halfWidth = Double.pi / Double(count) * 0.42
        func point(_ angle: Double) -> CGPoint {
            CGPoint(x: radius + cos(angle) * radius, y: radius + sin(angle) * radius)
        }
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * Double.pi
            path.move(to: CGPoint(x: radius, y: radius))
            path.addLine(to: point(angle - halfWidth))
            path.addLine(to: point(angle + halfWidth))
            path.closeSubpath()
        }
        return path
    }
}

/// The flare before it goes off: small and unseen.
private struct Flare: Sendable {
    var scale = 0.5
    var opacity = 0.0
}

/// A sparkle beside the revealed thing: its center, as a share of the thing's half-size from its
/// middle (so 1 is its edge), and its size in points.
private struct Sparkle: Sendable {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat

    /// Just past the sides, clear of anything above or below.
    static let all = [
        Sparkle(x: -1.12, y: -0.72, size: 22),
        Sparkle(x: 1.14, y: -0.46, size: 15),
        Sparkle(x: -1.1, y: 0.06, size: 12),
        Sparkle(x: 1.1, y: 0.18, size: 18),
        Sparkle(x: -1.14, y: 0.62, size: 16),
        Sparkle(x: 1.12, y: 0.74, size: 24),
    ]
}

private struct LightBurstPreview: View {
    @State private var isLit = false

    var body: some View {
        VStack(spacing: 40) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(WrappedStyle.ink)
                .frame(width: 220, height: 280)
                .background { LightBurst(isLit: isLit, size: CGSize(width: 220, height: 280)) }
            Button(isLit ? "Reset" : "Light it") { isLit.toggle() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x9D174D))
    }
}

#Preview("Light burst") {
    LightBurstPreview()
}
