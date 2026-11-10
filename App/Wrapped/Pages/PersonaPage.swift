import SwiftUI
import NoblesKit

/// Your cafe personality, revealed like a show. A foil card waits face down until you tap it.
/// Then it charges up, shaking and glowing, and flips over in a burst of light and confetti. The
/// persona's emoji, title and tagline come in one by one, with the numbers behind it below.
/// Once turned, it stays face up on later visits. Static mode shows it face up; under Reduce
/// Motion it cross-fades.
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

    private static let cardSize = CGSize(width: 290, height: 370)

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
                WrappedEyebrow("Your cafe personality", symbol: "sparkles")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Spacer(minLength: 0)
                card(isFaceUp: isFaceUp, isLit: isLit)
                    .wrappedReveal(isActive, delay: 0.25, style: .pop)
                // Both stay laid out, so the card doesn't move when one gives way to the other.
                ZStack(alignment: .top) {
                    WrappedHint("Tap the card to find out")
                        .opacity(isFaceUp ? 0 : 1)
                        .animation(.easeOut(duration: 0.2), value: isFaceUp)
                        .wrappedReveal(isActive, delay: 0.9, style: .fade)
                    Text(reason)
                        .font(WrappedStyle.body)
                        .foregroundStyle(WrappedStyle.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .wrappedReveal(isActive && isLit, delay: 0.7)
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
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .modifier(ChargeUp(isTapped: isTapped, isEnabled: !isStatic && !reduceMotion))
        .background { LightBurst(isLit: isLit, size: Self.cardSize) }
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
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

    /// The numbers behind the persona, in a sentence.
    private var reason: String {
        switch wrapped.persona {
        case .loyalist:
            guard let favorite = wrapped.favorite, wrapped.itemCount > 0 else { return wrapped.persona.tagline }
            let share = Double(favorite.count) / Double(wrapped.itemCount)
            return "\(favorite.name) was \(WrappedFormat.percent(share)) of everything you bought."
        case .nightOwl:
            return "\(WrappedFormat.percent(wrapped.share(ofHours: 17...23))) of your purchases came after 5 PM."
        case .earlyBird:
            return "\(WrappedFormat.percent(wrapped.share(ofHours: 0...9))) of your purchases came before 10 AM."
        case .regular:
            let days = WrappedFormat.count(wrapped.dayCount, "day")
            return wrapped.period.isComplete
                ? "You bought something on \(days), at least every other school day."
                : "You've bought something on \(days) so far, at least every other school day."
        case .explorer:
            return "You tried \(wrapped.distinctItemCount) different things."
        case .dropIn:
            return "You bought something \(WrappedFormat.count(wrapped.purchaseCount, "time")), with no set routine."
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
                    RoundedRectangle(cornerRadius: cardCornerRadius + 8, style: .continuous)
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

/// The persona card's corners.
private let cardCornerRadius: CGFloat = 32

/// The side you see first: foil, with a question mark. Its shimmer stops once it has turned away.
private struct PersonaCardBack: View {
    let isShimmering: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("?")
                .font(WrappedStyle.number(120))
            Text("Who are you\nat the cafe?")
                .font(WrappedStyle.lead)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(WrappedStyle.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            FoilSurface(cornerRadius: cardCornerRadius, isShimmering: isShimmering)
                // A light wash, so the dark text stays clear over the foil's darkest creases.
                .overlay { Color.white.opacity(0.22) }
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        }
    }
}

/// The revealed side: the persona's emoji, title and tagline on a dark card in a frame of foil,
/// each coming in once the card has turned.
private struct PersonaCardFront: View {
    let persona: CafePersona
    let isRevealed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
        VStack(spacing: 16) {
            Text(persona.emoji)
                .font(WrappedStyle.emoji(96))
                .wrappedReveal(isRevealed, delay: 0.1, style: .pop)
            Text(persona.title)
                .font(WrappedStyle.title(28))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isRevealed, delay: 0.3)
            Text(persona.tagline)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .wrappedReveal(isRevealed, delay: 0.45)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque, so the light behind the card never shows through the text.
        .background {
            shape
                .fill(WrappedStyle.ink)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
        }
        .overlay {
            FoilSurface(cornerRadius: cardCornerRadius)
                .mask { shape.strokeBorder(lineWidth: 6) }
        }
    }
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
