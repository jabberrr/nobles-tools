import SwiftUI

/// Wraps an item in a puffy bundle of crumpled foil and tears it open in stages, one per tap.
///
/// The foil is a photo of real foil cut to a lumpy, pinched bundle well bigger than the item, so
/// its outline gives nothing away. It grows to cover a big item's box (`item`) with room to spare,
/// stretching only partway toward its proportions. Whatever `content` draws around the item (a
/// plate) shows around the bundle. With four taps, the first tears a small jagged hole a little off the middle,
/// showing a bit of the item. The second tears it wider and folds its edge back: a band of the
/// foil's duller inside rolled over at a bright crest, casting a shadow on the item. The third
/// leaves only a ragged rim around the item. The last crumples the rim into a ball that hops and
/// drops away while the item pops, and `onUnwrap` runs. Other tap counts spread the hole's growth
/// evenly over the taps before the last. Every tap has a haptic and a squish, and the hole tears
/// wider with a spring.
///
/// The foil takes taps on the content's frame until it has dropped out of sight; then taps pass
/// through. `initialTaps` starts it that far along, drawn at once, for snapshots. Static mode
/// draws the stage without moving; under Reduce Motion stages cross-fade. VoiceOver finds one
/// button that tears the foil a stage further each time it's activated.
struct FoilWrap<Content: View>: View {
    private let tapsToUnwrap: Int
    private let item: FoilItemBounds
    private let onTap: (Int) -> Void
    private let onUnwrap: () -> Void
    private let content: Content

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps: Int
    /// Whether the foil has dropped out of sight, so taps pass through.
    @State private var isGone: Bool

    /// - Parameters:
    ///   - initialTaps: Stages already done, drawn at once (for snapshots).
    ///   - item: The box the item fills in the middle of `content`, for the foil to cover.
    ///   - content: The picture under the foil.
    init(
        tapsToUnwrap: Int = 4,
        initialTaps: Int = 0,
        covering item: FoilItemBounds,
        onTap: @escaping (_ taps: Int) -> Void = { _ in },
        onUnwrap: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        let tapsToUnwrap = max(tapsToUnwrap, 1)
        let taps = min(max(initialTaps, 0), tapsToUnwrap)
        self.tapsToUnwrap = tapsToUnwrap
        self.item = item
        self.onTap = onTap
        self.onUnwrap = onUnwrap
        self.content = content()
        _taps = State(initialValue: taps)
        _isGone = State(initialValue: taps == tapsToUnwrap)
    }

    var body: some View {
        let stage = FoilStage(taps: taps, of: tapsToUnwrap)
        let motion = FoilMotion(isStatic: isStatic, reduceMotion: reduceMotion)
        content
            .modifier(UnwrapPop(isUnwrapped: stage.isOff, isEnabled: motion == .full))
            .accessibilityHidden(!stage.isOff)
            .overlay {
                if !isGone {
                    FoilCover(item: item, stage: stage, taps: taps, motion: motion)
                        .padding(-FoilGeometry.margin)
                        .allowsHitTesting(false)
                    tapTarget(isOff: stage.isOff)
                }
            }
            .sensoryFeedback(trigger: taps) { _, taps in
                taps >= tapsToUnwrap
                    ? SensoryFeedback.success
                    : SensoryFeedback.impact(flexibility: .soft, intensity: 0.8)
            }
            .task(id: stage.isOff) {
                guard stage.isOff, !isGone else { return }
                do {
                    try await Task.sleep(for: .seconds(motion.exitDuration))
                } catch {
                    return
                }
                isGone = true
            }
    }

    /// Takes taps on the content's frame, and is the foil's one VoiceOver button.
    private func tapTarget(isOff: Bool) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { advance() }
            .accessibilityElement()
            .accessibilityLabel("Wrapped in foil")
            .accessibilityValue(tapsLeft == 1 ? "1 tap left" : "\(tapsLeft) taps left")
            .accessibilityHint(nextTapHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { advance() }
            .accessibilityHidden(isOff)
    }

    private var tapsLeft: Int {
        tapsToUnwrap - taps
    }

    /// What the next tap does.
    private var nextTapHint: String {
        if tapsLeft == 1 {
            "Takes the foil off"
        } else if taps == 0 {
            "Tears a hole in the foil"
        } else {
            "Tears the hole wider"
        }
    }

    private func advance() {
        guard taps < tapsToUnwrap else { return }
        taps += 1
        onTap(taps)
        if taps == tapsToUnwrap {
            onUnwrap()
        }
    }
}

/// How far the foil has come off: how wide its hole is torn, and whether it's off.
struct FoilStage: Equatable, Sendable {
    /// How wide the hole is torn: 0 before the first tap, 1 once only a rim is left.
    let openness: Double
    let isOff: Bool

    /// The stage after `taps` of `total` taps: the last one takes the foil off, and the ones
    /// before it tear the hole wider in even steps.
    init(taps: Int, of total: Int) {
        isOff = taps >= total
        openness = isOff ? 1 : Double(max(taps, 0)) / Double(max(total - 1, 1))
    }
}

/// How the foil moves: not at all in snapshots, in cross-fades under Reduce Motion, else fully.
enum FoilMotion: Sendable {
    case still, reduced, full

    init(isStatic: Bool, reduceMotion: Bool) {
        self = isStatic ? .still : (reduceMotion ? .reduced : .full)
    }

    /// Seconds from the last tap until the foil is out of sight.
    var exitDuration: Double {
        self == .full ? 1.1 : 0.4
    }
}

/// The item's pop as the foil comes off: a quick swell, then a bounce back.
private struct UnwrapPop: ViewModifier {
    let isUnwrapped: Bool
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.keyframeAnimator(initialValue: 1.0, trigger: isUnwrapped) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1, duration: 0.2)
                    SpringKeyframe(1.12, duration: 0.18, spring: .snappy)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Previews

/// A stand-in for the favorite's picture: a cookie on a plate, or (as its silhouette) the cookie
/// alone.
private struct PreviewCookie: View {
    var isSilhouette = false

    var body: some View {
        Text("🍪")
            .font(WrappedStyle.emoji(110))
            .frame(width: 220, height: 220)
            .background {
                if !isSilhouette {
                    Circle().fill(
                        RadialGradient(
                            colors: [Color(hex: 0xFFF9EF), Color(hex: 0xF2AE63)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                }
            }
    }
}

private let previewTaps = 4

private struct FoilWrapPreview: View {
    @State private var taps = 0
    @State private var wrapping = 0

    var body: some View {
        VStack(spacing: 36) {
            FoilWrap(tapsToUnwrap: previewTaps, onTap: { taps = $0 }) {
                PreviewCookie()
            } silhouette: {
                PreviewCookie(isSilhouette: true)
            }
            .id(wrapping)
            Text(taps >= previewTaps ? "Unwrapped" : "\(previewTaps - taps) to go")
                .font(WrappedStyle.lead)
                .foregroundStyle(.white)
            Button("Wrap again") {
                taps = 0
                wrapping += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x2E1A87))
    }
}

#Preview("Foil wrap") {
    FoilWrapPreview()
}

#Preview("Foil wrap stages (static)") {
    ScrollView {
        VStack(spacing: 70) {
            ForEach(0...previewTaps, id: \.self) { taps in
                FoilWrap(tapsToUnwrap: previewTaps, initialTaps: taps) {
                    PreviewCookie()
                } silhouette: {
                    PreviewCookie(isSilhouette: true)
                }
            }
        }
        .padding(70)
        .frame(maxWidth: .infinity)
    }
    .background(Color(hex: 0x2E1A87))
    .environment(\.wrappedIsStatic, true)
}
