import SwiftUI

/// The foil over an item at one stage, filling the content's frame plus `FoilGeometry.margin` on
/// every side. Each tap tears its hole wider with a spring, or cross-fades to the next stage under
/// Reduce Motion. Once the foil is off, what's left of it crumples into a ball that drops out of
/// sight.
struct FoilCover<Silhouette: View>: View {
    let silhouette: Silhouette
    let stage: FoilStage
    /// Taps so far: each one squishes the foil.
    let taps: Int
    let motion: FoilMotion

    var body: some View {
        GeometryReader { proxy in
            let geometry = FoilGeometry(size: proxy.size)
            ZStack {
                foil(geometry)
                if motion == .full {
                    FoilBall(diameter: geometry.ballDiameter)
                        .modifier(BallDrop(isDropping: stage.isOff, distance: geometry.size.height * 0.75))
                }
            }
        }
    }

    /// The foil at this stage, crumpling toward the middle and vanishing into the ball once it's
    /// off.
    private func foil(_ geometry: FoilGeometry) -> some View {
        let isCrumpling = stage.isOff && motion == .full
        return ZStack {
            FoilLayers(silhouette: silhouette, geometry: geometry, openness: stage.openness)
                // Under Reduce Motion each stage is a new view, so it cross-fades in.
                .id(motion == .reduced ? taps : 0)
                .transition(.opacity)
        }
        .animation(stageAnimation, value: taps)
        .modifier(TapSquish(taps: taps, isEnabled: motion == .full))
        .scaleEffect(isCrumpling ? 0.3 : 1)
        .rotationEffect(.degrees(isCrumpling ? 40 : 0))
        .animation(.easeIn(duration: 0.3), value: stage.isOff)
        .opacity(stage.isOff ? 0 : 1)
        .animation(fadeAnimation, value: stage.isOff)
    }

    /// The hole tears wider with a spring, or the stages cross-fade under Reduce Motion.
    private var stageAnimation: Animation? {
        switch motion {
        case .full: .spring(duration: 0.55, bounce: 0.3)
        case .reduced: .easeInOut(duration: 0.35)
        case .still: nil
        }
    }

    /// The rim fades as it shrinks into the ball, or simply fades under Reduce Motion.
    private var fadeAnimation: Animation {
        motion == .full ? .easeIn(duration: 0.12).delay(0.2) : .easeInOut(duration: 0.35)
    }
}

/// A squish and a wobble at each tap.
private struct TapSquish: ViewModifier {
    let taps: Int
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.keyframeAnimator(initialValue: Squish(), trigger: taps) { view, squish in
                view
                    .scaleEffect(x: squish.width, y: squish.height)
                    .rotationEffect(.degrees(squish.turn))
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    CubicKeyframe(1.07, duration: 0.08)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.height) {
                    CubicKeyframe(0.9, duration: 0.08)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
                KeyframeTrack(\.turn) {
                    CubicKeyframe(-3, duration: 0.07)
                    CubicKeyframe(2.5, duration: 0.09)
                    CubicKeyframe(-1.2, duration: 0.09)
                    CubicKeyframe(0, duration: 0.12)
                }
            }
        } else {
            content
        }
    }
}

private struct Squish: Sendable {
    var width = 1.0
    var height = 1.0
    /// Degrees.
    var turn = 0.0
}

/// The ball's moment once the foil is off: it balls up out of the crumpling rim, hops, and drops
/// `distance` points out of sight, spinning.
private struct BallDrop: ViewModifier {
    let isDropping: Bool
    let distance: CGFloat

    func body(content: Content) -> some View {
        let fall = Double(distance)
        return content.keyframeAnimator(initialValue: BallMotion(), trigger: isDropping) { ball, motion in
            ball
                .scaleEffect(motion.scale)
                .rotationEffect(.degrees(motion.spin))
                .offset(y: motion.drop)
                .opacity(motion.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                LinearKeyframe(0.55, duration: 0.16)
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(0, duration: 0.14)
                LinearKeyframe(1, duration: 0.08)
                LinearKeyframe(1, duration: 0.6)
                LinearKeyframe(0, duration: 0.25)
            }
            KeyframeTrack(\.drop) {
                LinearKeyframe(0, duration: 0.34)
                LinearKeyframe(-16, duration: 0.14, timingCurve: .easeOut)
                LinearKeyframe(fall, duration: 0.55, timingCurve: .easeIn)
            }
            KeyframeTrack(\.spin) {
                LinearKeyframe(0, duration: 0.3)
                LinearKeyframe(240, duration: 0.75, timingCurve: .easeIn)
            }
        }
    }
}

/// The ball before it appears: small, unseen, unturned.
private struct BallMotion: Sendable {
    var scale = 0.55
    var opacity = 0.0
    var drop = 0.0
    /// Degrees.
    var spin = 0.0
}
