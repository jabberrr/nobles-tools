import SwiftUI
import NoblesKit

/// Your cafe personality, revealed like a show. A foil card with a "?" stamped into it waits face
/// down until you tap it. Then it charges up, shaking and glowing, and flips over in a burst of
/// light and confetti. The persona's emoji, title and tagline come in one by one, with the figure
/// behind it below. Once turned, it stays face up on later visits. Static mode shows it face up;
/// under Reduce Motion it cross-fades.
struct PersonaPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool
    /// Whether the card has been turned over, kept by the story across visits.
    @Binding var isRevealed: Bool

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether the card has been tapped, which starts the show.
    @State private var isTapped: Bool
    /// Whether the card's front has come into view: the light bursts, confetti flies, and taps
    /// on the card go back to turning the page.
    @State private var hasLanded: Bool

    /// A visit that begins with the card already turned shows it face up, with no show.
    init(wrapped: CafeWrapped, isActive: Bool, isRevealed: Binding<Bool>) {
        self.wrapped = wrapped
        self.isActive = isActive
        _isRevealed = isRevealed
        _isTapped = State(initialValue: isRevealed.wrappedValue)
        _hasLanded = State(initialValue: isRevealed.wrappedValue)
    }

    var body: some View {
        let isFaceUp = isStatic || isTapped
        let isLit = isStatic || hasLanded
        ZStack {
            VStack(spacing: 24) {
                WrappedEyebrow("Your cafe personality")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Spacer(minLength: 0)
                card(isFaceUp: isFaceUp, isLit: isLit)
                    .wrappedReveal(isActive, delay: 0.25, style: .pop)
                // Both stay laid out, so the card doesn't move when one gives way to the other.
                ZStack(alignment: .top) {
                    WrappedHint("Tap to reveal")
                        .opacity(isFaceUp ? 0 : 1)
                        .animation(.easeOut(duration: 0.2), value: isFaceUp)
                        .wrappedReveal(isActive, delay: 0.9, style: .fade)
                    if let evidence = PersonaEvidence(wrapped) {
                        evidenceView(evidence, isRevealed: isActive && isLit)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.top, 20)
            .padding(.bottom, 24)
            ConfettiBurst(trigger: hasLanded ? 1 : 0, emojis: [wrapped.persona.emoji])
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isTapped)
        .sensoryFeedback(.success, trigger: hasLanded)
        .task(id: isTapped) {
            guard isTapped, !hasLanded else { return }
            do {
                try await Task.sleep(for: .seconds(reduceMotion ? Show.fadedLanding : Show.landing))
            } catch {
                return
            }
            hasLanded = true
        }
    }

    /// Both faces turn together, each showing only while it faces forward; they swap halfway
    /// through the turn. Under Reduce Motion they cross-fade instead.
    private func card(isFaceUp: Bool, isLit: Bool) -> some View {
        let turns = !reduceMotion
        return ZStack {
            PersonaCardBack(isShimmering: !isFaceUp)
                .opacity(isFaceUp ? 0 : 1)
                .animation(faceSwap, value: isFaceUp)
                .rotation3DEffect(.degrees(turns && isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            PersonaCardFront(persona: wrapped.persona, isRevealed: isLit)
                .opacity(isFaceUp ? 1 : 0)
                .animation(faceSwap, value: isFaceUp)
                .rotation3DEffect(.degrees(turns && !isFaceUp ? -180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        }
        .animation(.easeInOut(duration: Show.flip).delay(Show.charge), value: isFaceUp)
        .frame(width: PersonaCard.size.width, height: PersonaCard.size.height)
        .modifier(ChargeUp(isTapped: isTapped, isEnabled: !isStatic && !reduceMotion))
        .background { LightBurst(isLit: isLit, size: PersonaCard.size) }
        .contentShape(RoundedRectangle(cornerRadius: PersonaCard.cornerRadius, style: .continuous))
        // Until it has turned, the card takes taps; then they turn the page like anywhere else.
        .gesture(TapGesture().onEnded { reveal() }, including: isLit ? .subviews : .all)
    }

    /// Starts the show, and has the story remember the card is turned even if you leave mid-show.
    private func reveal() {
        guard !isTapped else { return }
        isTapped = true
        isRevealed = true
    }

    private var faceSwap: Animation {
        reduceMotion ? .easeInOut(duration: 0.4) : .linear(duration: 0.01).delay(Show.landing)
    }

    /// The figure behind the persona, over what it counts.
    private func evidenceView(_ evidence: PersonaEvidence, isRevealed: Bool) -> some View {
        VStack(spacing: 2) {
            Text(evidence.figure)
                .font(WrappedStyle.number(30))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isRevealed, delay: 0.7, style: .pop)
            Text(evidence.label)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isRevealed, delay: 0.85)
        }
    }
}

/// The show's timing, in seconds from the tap.
private enum Show {
    /// The card shakes and glows this long before it turns.
    static let charge = 0.5
    /// How long the turn takes.
    static let flip = 0.6
    /// When the front comes into view, halfway through the turn.
    static let landing = charge + flip / 2
    /// When the front is mostly in view under Reduce Motion, partway through the cross-fade.
    static let fadedLanding = 0.25
}

/// The card charging up before it turns: it trembles harder and harder, swells and glows, then
/// settles as it flips.
private struct ChargeUp: ViewModifier {
    let isTapped: Bool
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .background {
                    RoundedRectangle(cornerRadius: PersonaCard.cornerRadius + 8, style: .continuous)
                        .fill(WrappedStyle.highlight)
                        .blur(radius: 24)
                        .keyframeAnimator(initialValue: 0.0, trigger: isTapped) { glow, opacity in
                            glow.opacity(opacity)
                        } keyframes: { _ in
                            KeyframeTrack {
                                LinearKeyframe(0.9, duration: Show.charge)
                                LinearKeyframe(0.9, duration: 0.2)
                                LinearKeyframe(0, duration: 0.6)
                            }
                        }
                }
                .keyframeAnimator(initialValue: Charge(), trigger: isTapped) { card, charge in
                    card
                        .scaleEffect(charge.scale)
                        .rotationEffect(.degrees(charge.shake))
                } keyframes: { _ in
                    KeyframeTrack(\.shake) {
                        LinearKeyframe(1.5, duration: 0.06)
                        LinearKeyframe(-2, duration: 0.06)
                        LinearKeyframe(2.5, duration: 0.06)
                        LinearKeyframe(-3, duration: 0.06)
                        LinearKeyframe(3.5, duration: 0.06)
                        LinearKeyframe(-3.5, duration: 0.06)
                        LinearKeyframe(2, duration: 0.05)
                        LinearKeyframe(0, duration: 0.05)
                    }
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.06, duration: Show.charge)
                        SpringKeyframe(1, duration: 0.6, spring: .bouncy)
                    }
                }
        } else {
            content
        }
    }
}

/// The card at rest: still and its normal size.
private struct Charge: Sendable {
    /// Degrees.
    var shake = 0.0
    var scale = 1.0
}

private struct PersonaPagePreview: View {
    @State private var isRevealed = false

    var body: some View {
        PersonaPage(wrapped: .sample, isActive: true, isRevealed: $isRevealed)
            .foregroundStyle(.white)
            .background(Color(hex: 0x9D174D))
    }
}

#Preview {
    PersonaPagePreview()
}
