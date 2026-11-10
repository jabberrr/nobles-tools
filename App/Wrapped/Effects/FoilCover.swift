import SwiftUI

/// The foil over an item at one stage, filling the content's frame plus `FoilGeometry.margin` on
/// every side: its three flaps, squishing at each tap, and once it's off, the ball it crumples
/// into, dropping out of sight.
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
                flaps(geometry)
                if motion == .full {
                    FoilBall(diameter: geometry.ballDiameter)
                        .modifier(BallDrop(isDropping: stage.isOff, distance: geometry.size.height * 0.75))
                }
            }
        }
    }

    /// The flaps, which crumple toward the middle and vanish into the ball once the foil is off.
    private func flaps(_ geometry: FoilGeometry) -> some View {
        let isCrumpling = stage.isOff && motion == .full
        return ZStack {
            ForEach(FoilRegion.drawingOrder, id: \.self) { region in
                FoilFlap(region: region, stage: stage, motion: motion, geometry: geometry, silhouette: silhouette)
            }
        }
        .foilShimmer(isActive: !stage.isOff, strength: FoilArt.sweepStrength)
        .modifier(TapSquish(taps: taps, isEnabled: motion == .full))
        .scaleEffect(isCrumpling ? 0.3 : 1)
        .rotationEffect(.degrees(isCrumpling ? 40 : 0))
        .animation(.easeIn(duration: 0.3), value: stage.isOff)
        .opacity(stage.isOff ? 0 : 1)
        .animation(fadeAnimation, value: stage.isOff)
    }

    /// The flaps fade as they shrink into the ball, or simply fade under Reduce Motion.
    private var fadeAnimation: Animation {
        motion == .full ? .easeIn(duration: 0.12).delay(0.2) : .easeInOut(duration: 0.35)
    }
}

/// One flap of the foil.
///
/// Wrapped, it's a shiny piece over a dark gap that shows along the seams once it loosens and
/// lifts. Opening, a hole in the item's shape grows from the flap's free edge out to the item's
/// edge, with the foil's rolled edge riding along it, and the opened-out foil fades in around the
/// item. Under Reduce Motion the wrapped piece fades out and the opened foil fades in.
private struct FoilFlap<Silhouette: View>: View {
    let region: FoilRegion
    let stage: FoilStage
    let motion: FoilMotion
    let geometry: FoilGeometry
    let silhouette: Silhouette

    var body: some View {
        let isOpen = stage.isOpen(region)
        let lift = FlapLift(region: region, geometry: geometry)
        ZStack {
            piece(.opened(region))
                .shadow(color: .black.opacity(0.25), radius: 3 * geometry.unit, y: 2 * geometry.unit)
                .opacity(isOpen ? 1 : 0)
                .animation(openingAnimation, value: isOpen)
            ZStack {
                piece(.gap(region))
                piece(.wrapped(region))
                    .offset(stage.isLoose ? lift.offset : .zero)
                    .rotation3DEffect(
                        .degrees(stage.isLoose && motion != .reduced ? lift.degrees : 0),
                        axis: lift.axis,
                        anchor: lift.anchor,
                        perspective: 0.3
                    )
                    .brightness(stage.isLoose ? 0.03 : 0)
                    .animation(liftAnimation, value: stage.isLoose)
            }
            .mask { peelMask(isOpen: isOpen) }
            .opacity(motion == .reduced && isOpen ? 0 : 1)
            .animation(.easeInOut(duration: 0.35), value: isOpen)
            piece(.curl(region))
                .scaleEffect(motion == .reduced || isOpen ? 1 : peeledShut, anchor: geometry.peelAnchor(of: region))
                .shadow(color: .black.opacity(0.35), radius: 2.5 * geometry.unit, y: geometry.unit)
                .opacity(isOpen ? 1 : 0)
                .animation(peelAnimation, value: isOpen)
        }
    }

    /// Everything but the hole peeled so far. Under Reduce Motion there's no hole: the flap fades.
    private func peelMask(isOpen: Bool) -> some View {
        Rectangle()
            .overlay {
                if motion != .reduced {
                    piece(.hole)
                        .scaleEffect(isOpen ? 1 : peeledShut, anchor: geometry.peelAnchor(of: region))
                        .animation(peelAnimation, value: isOpen)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
    }

    private var liftAnimation: Animation {
        motion == .full ? .spring(duration: 0.4, bounce: 0.45) : .easeInOut(duration: 0.3)
    }

    private var peelAnimation: Animation {
        motion == .full ? .spring(duration: 0.8, bounce: 0.1) : .easeInOut(duration: 0.35)
    }

    /// The opened foil spreads out as the peel reaches the item's edge.
    private var openingAnimation: Animation {
        motion == .full ? .easeOut(duration: 0.4).delay(0.3) : .easeInOut(duration: 0.35)
    }

    private func piece(_ spec: FoilPieceSpec) -> FoilPiece<Silhouette> {
        FoilPiece(spec: spec, geometry: geometry, silhouette: silhouette)
    }
}

/// The scale of a hole that hasn't started: not quite zero, which some renderers reject.
private let peeledShut: CGFloat = 0.001

/// How a flap lifts once the foil loosens: away from its seams, its free edge tipped up.
private struct FlapLift {
    let offset: CGSize
    let degrees: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    /// The edge it hinges on, where it's still tucked around the item.
    let anchor: UnitPoint

    init(region: FoilRegion, geometry: FoilGeometry) {
        let unit = geometry.unit
        let size = geometry.size
        let item = geometry.itemFrame
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        switch region {
        case .top:
            offset = CGSize(width: 0, height: -2.5 * unit)
            degrees = 9
            axis = (x: 1, y: 0, z: 0)
            anchor = UnitPoint(x: 0.5, y: item.minY / height)
        case .left:
            offset = CGSize(width: -2 * unit, height: 0)
            degrees = -8
            axis = (x: 0, y: 1, z: 0)
            anchor = UnitPoint(x: item.minX / width, y: 0.6)
        case .right:
            offset = CGSize(width: 2 * unit, height: 0)
            degrees = 8
            axis = (x: 0, y: 1, z: 0)
            anchor = UnitPoint(x: item.maxX / width, y: 0.6)
        }
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

/// The ball's moment once the foil is off: it balls up out of the crumpling flaps, hops, and
/// drops `distance` points out of sight, spinning.
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
