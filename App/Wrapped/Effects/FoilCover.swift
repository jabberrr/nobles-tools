import SwiftUI

/// The foil over an item at one stage, filling the content's frame plus `FoilGeometry.margin` on
/// every side. Every piece is the foil photo cut to the item's grown silhouette with masks, so the
/// foil is always shaped like the item and the item shows only where the foil has opened. Once
/// the foil is off, it crumples into a ball that drops out of sight.
struct FoilCover<Silhouette: View>: View {
    let silhouette: Silhouette
    let stage: FoilStage
    /// Taps so far: each one squishes the foil.
    let taps: Int
    let motion: FoilMotion

    var body: some View {
        GeometryReader { proxy in
            let masks = FoilMasks(silhouette: silhouette, geometry: FoilGeometry(size: proxy.size))
            ZStack {
                foil(masks)
                if motion == .full {
                    FoilBall(diameter: masks.geometry.ballDiameter)
                        .modifier(BallDrop(isDropping: stage.isOff, distance: masks.geometry.size.height * 0.75))
                }
            }
        }
    }

    /// The flaps over the opened foil and the gap, crumpling toward the middle and vanishing into
    /// the ball once the foil is off.
    private func foil(_ masks: FoilMasks<Silhouette>) -> some View {
        let isCrumpling = stage.isOff && motion == .full
        return ZStack {
            if stage.step >= 2 {
                opened(masks)
                    .transition(.opacity)
            }
            if stage.isLoose && stage.step < 4 {
                gap(masks)
            }
            ForEach(FoilRegion.drawingOrder, id: \.self) { region in
                FoilFlap(region: region, stage: stage, motion: motion, masks: masks)
            }
        }
        .animation(openingAnimation, value: stage.step)
        .foilShimmer(isActive: !stage.isOff, strength: FoilArt.sweepStrength)
        .modifier(TapSquish(taps: taps, isEnabled: motion == .full))
        .scaleEffect(isCrumpling ? 0.3 : 1)
        .rotationEffect(.degrees(isCrumpling ? 40 : 0))
        .animation(.easeIn(duration: 0.3), value: stage.isOff)
        .opacity(stage.isOff ? 0 : 1)
        .animation(fadeAnimation, value: stage.isOff)
    }

    /// The foil opened out and left crumpled around the item, under every flap that has opened.
    private func opened(_ masks: FoilMasks<Silhouette>) -> some View {
        let unit = masks.geometry.unit
        return FoilFinish(face: .inside, geometry: masks.geometry)
            .mask { masks.ring(FoilGrowth.opened, rumple: 0.35, seed: 0x0FE2) }
            .mask {
                ZStack {
                    ForEach(FoilRegion.allCases, id: \.self) { region in
                        masks.region(region)
                            .opacity(stage.isOpen(region) ? 1 : 0)
                    }
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 3 * unit, y: 2 * unit)
    }

    /// The dark gap under the flaps still wrapped, which shows along the seams once they lift.
    /// A flap's part goes the moment it starts to peel, so the item shows through its hole.
    private func gap(_ masks: FoilMasks<Silhouette>) -> some View {
        Color(white: 0.06, opacity: 0.85)
            .mask { masks.grown(FoilGrowth.gap, rumple: FoilGrowth.wrapRumple, seed: FoilGrowth.wrapSeed) }
            .mask {
                ZStack {
                    ForEach(FoilRegion.allCases, id: \.self) { region in
                        if !stage.isOpen(region) {
                            masks.region(region)
                        }
                    }
                }
            }
            .transaction { $0.animation = nil }
    }

    /// The opened foil spreads out as a peel reaches the item's edge.
    private var openingAnimation: Animation {
        motion == .full ? .easeOut(duration: 0.4).delay(0.3) : .easeInOut(duration: 0.35)
    }

    /// The flaps fade as they shrink into the ball, or simply fade under Reduce Motion.
    private var fadeAnimation: Animation {
        motion == .full ? .easeIn(duration: 0.12).delay(0.2) : .easeInOut(duration: 0.35)
    }
}

/// One flap of the foil.
///
/// Wrapped, it's the shiny outside cut to the flap, its edges shaded so it looks puffed up and
/// its folds creased. Loose, it lifts off its seams. Opening, a hole in the item's shape grows
/// from the flap's free edge out to the item's edge, so the item shows through, and the foil's
/// rolled edge rides along the hole. Under Reduce Motion the flap fades out and its rolled edge
/// fades in.
private struct FoilFlap<Silhouette: View>: View {
    let region: FoilRegion
    let stage: FoilStage
    let motion: FoilMotion
    let masks: FoilMasks<Silhouette>

    var body: some View {
        let isOpen = stage.isOpen(region)
        let lift = FlapLift(region: region, geometry: masks.geometry)
        let anchor = masks.geometry.peelAnchor(of: region)
        ZStack {
            wrapped
                .offset(stage.isLoose ? lift.offset : .zero)
                .rotation3DEffect(
                    .degrees(stage.isLoose && motion != .reduced ? lift.degrees : 0),
                    axis: lift.axis,
                    anchor: lift.anchor,
                    perspective: 0.3
                )
                .brightness(stage.isLoose ? 0.03 : 0)
                .animation(liftAnimation, value: stage.isLoose)
                .mask { peelMask(isOpen: isOpen, anchor: anchor) }
                .opacity(motion == .reduced && isOpen ? 0 : 1)
            // Built only once the flap opens: it grows out from the hole's start.
            if isOpen {
                curl
                    .shadow(color: .black.opacity(0.35), radius: 2.5 * masks.geometry.unit, y: masks.geometry.unit)
                    .transition(curlTransition(anchor: anchor))
            }
        }
        .animation(peelAnimation, value: isOpen)
    }

    /// The flap's outside: the shiny face, its edges shaded so it looks puffed up, its folds
    /// creased, cut to the wrap and to the flap.
    private var wrapped: some View {
        let unit = masks.geometry.unit
        return FoilFinish(face: .outside, geometry: masks.geometry)
            .overlay { rim(.black.opacity(0.4), shift: CGSize(width: -2.5 * unit, height: -3.5 * unit), blur: 3 * unit) }
            .overlay { rim(.white.opacity(0.6), shift: CGSize(width: 1.5 * unit, height: 2 * unit), blur: unit) }
            .overlay { FoilFolds(region: region, geometry: masks.geometry) }
            .mask { masks.wrap() }
            .mask { masks.region(region) }
    }

    /// `color` wherever the wrap lies outside its own outline moved by `shift`: a band along the
    /// edges that face away from the shift.
    private func rim(_ color: Color, shift: CGSize, blur: CGFloat) -> some View {
        color
            .foilCutout { masks.wrap(copies: 8).offset(shift) }
            .blur(radius: blur)
    }

    /// The rolled edge of the peeled flap, hugging the item: the foil's inside, brightest along
    /// the fold at its outer edge.
    private var curl: some View {
        FoilFinish(face: .inside, geometry: masks.geometry)
            .overlay { Color.black.opacity(0.25) }
            .overlay {
                Color.white.opacity(0.75)
                    .foilCutout { masks.grown(FoilGrowth.curl - 2.5, copies: 8) }
                    .blur(radius: masks.geometry.unit)
            }
            .mask { masks.ring(FoilGrowth.curl) }
            .mask { masks.region(region) }
    }

    /// Everything but the part peeled so far: the item's shape, grown from the flap's free edge.
    /// Under Reduce Motion there's no hole; the flap fades instead.
    private func peelMask(isOpen: Bool, anchor: UnitPoint) -> some View {
        Rectangle()
            .foilCutout {
                if motion != .reduced {
                    masks.grown(FoilGrowth.hole)
                        .scaleEffect(isOpen ? 1 : peeledShut, anchor: anchor)
                }
            }
    }

    private func curlTransition(anchor: UnitPoint) -> AnyTransition {
        motion == .reduced ? .opacity : .scale(scale: peeledShut, anchor: anchor).combined(with: .opacity)
    }

    private var liftAnimation: Animation {
        motion == .full ? .spring(duration: 0.4, bounce: 0.45) : .easeInOut(duration: 0.3)
    }

    private var peelAnimation: Animation {
        motion == .full ? .spring(duration: 0.8, bounce: 0.1) : .easeInOut(duration: 0.35)
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
