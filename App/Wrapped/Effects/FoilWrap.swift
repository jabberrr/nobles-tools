import SwiftUI

/// Wraps an item in crumpled foil shaped like it, which comes off in stages, one per tap.
///
/// The foil is a photo of real foil cut to the item's `silhouette`, grown a little and puffed up
/// with light and shade, with folds where its three flaps overlap. It covers only the item, so
/// whatever `content` draws around it (a plate) stays in view. The first tap loosens it, so
/// the flaps lift and the seams open. The next three peel back the top, then the left side, then
/// the right, each rolling back from its seam to the item's edge and leaving the opened foil
/// crumpled around the item. The last tap crumples it all into a ball that hops and drops away
/// while the item pops, and `onUnwrap` runs. Other tap counts spread the same stages out. Every
/// tap has a haptic and a squish.
///
/// The foil takes taps on the content's frame until it has dropped out of sight; then taps pass
/// through. `initialTaps` starts it that far along, drawn at once, for snapshots. Static mode
/// draws the stage without moving; under Reduce Motion stages cross-fade. VoiceOver finds one
/// button that peels a stage each time it's activated.
struct FoilWrap<Content: View, Silhouette: View>: View {
    private let tapsToUnwrap: Int
    private let onTap: (Int) -> Void
    private let onUnwrap: () -> Void
    private let content: Content
    private let silhouette: Silhouette

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps: Int
    /// Whether the foil has dropped out of sight, so taps pass through.
    @State private var isGone: Bool

    /// - Parameters:
    ///   - initialTaps: Stages already done, drawn at once (for snapshots).
    ///   - content: The picture under the foil.
    ///   - silhouette: The item's shape: opaque where the item is, laid out exactly like `content`.
    init(
        tapsToUnwrap: Int = 5,
        initialTaps: Int = 0,
        onTap: @escaping (_ taps: Int) -> Void = { _ in },
        onUnwrap: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content,
        @ViewBuilder silhouette: () -> Silhouette
    ) {
        let tapsToUnwrap = max(tapsToUnwrap, 1)
        let taps = min(max(initialTaps, 0), tapsToUnwrap)
        self.tapsToUnwrap = tapsToUnwrap
        self.onTap = onTap
        self.onUnwrap = onUnwrap
        self.content = content()
        self.silhouette = silhouette()
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
                    FoilCover(silhouette: silhouette, stage: stage, taps: taps, motion: motion)
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
            .accessibilityHint("Peels off some foil.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { advance() }
            .accessibilityHidden(isOff)
    }

    private var tapsLeft: Int {
        tapsToUnwrap - taps
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

/// How far the foil has come off: it loosens, its top, left and right flaps peel back in turn,
/// and the last tap takes it off.
struct FoilStage: Equatable, Sendable {
    /// Peel steps done: 1 loosens it, then 2, 3 and 4 open the top, the left and the right.
    let step: Int
    let isOff: Bool

    /// The stage after `taps` of `total` taps: the last one takes the foil off, and the ones
    /// before it spread over the four peel steps.
    init(taps: Int, of total: Int) {
        isOff = taps >= total
        if isOff {
            step = 4
        } else if total <= 1 {
            step = 0
        } else {
            step = min(Int((Double(max(taps, 0)) * 4 / Double(total - 1)).rounded(.up)), 4)
        }
    }

    var isLoose: Bool {
        step >= 1
    }

    func isOpen(_ region: FoilRegion) -> Bool {
        switch region {
        case .top: step >= 2
        case .left: step >= 3
        case .right: step >= 4
        }
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

private struct FoilWrapPreview: View {
    @State private var taps = 0
    @State private var wrapping = 0

    var body: some View {
        VStack(spacing: 36) {
            FoilWrap(onTap: { taps = $0 }) {
                PreviewCookie()
            } silhouette: {
                PreviewCookie(isSilhouette: true)
            }
            .id(wrapping)
            Text(taps >= 5 ? "It's off" : "Tap the foil (\(5 - taps) to go)")
                .font(WrappedStyle.lead)
                .foregroundStyle(.white)
            Button("Wrap it again") {
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
            ForEach(0..<5) { taps in
                FoilWrap(initialTaps: taps) {
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
