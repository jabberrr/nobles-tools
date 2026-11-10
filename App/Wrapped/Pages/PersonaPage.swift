import SwiftUI
import NoblesKit

/// Your cafe personality: a foil card that flips over by itself (or at a tap) to reveal it, with
/// confetti and the stat behind it.
struct PersonaPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    @State private var isFlipped = false
    @State private var confetti = 0
    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let flipDuration = 0.7

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                WrappedEyebrow("Your cafe personality", symbol: "sparkles")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Spacer(minLength: 0)
                card
                    .wrappedReveal(isActive, delay: 0.25, style: .pop)
                Text(reason)
                    .font(WrappedStyle.body)
                    .foregroundStyle(WrappedStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive && showsFront, delay: 0.5)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.top, 20)
            .padding(.bottom, 24)
            ConfettiBurst(trigger: confetti, emojis: [wrapped.persona.emoji])
        }
        .task(id: isActive) {
            guard isActive, !isFlipped else { return }
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            flip()
        }
    }

    /// Snapshots show the revealed side.
    private var showsFront: Bool {
        isStatic || isFlipped
    }

    /// Both faces turn together; each shows only while it faces forward, swapping halfway through
    /// the turn. Under Reduce Motion they cross-fade instead.
    private var card: some View {
        ZStack {
            PersonaCardBack(isShimmering: isActive && !showsFront)
                .opacity(showsFront ? 0 : 1)
                .animation(faceSwap, value: showsFront)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (showsFront ? 180 : 0)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            PersonaCardFront(persona: wrapped.persona)
                .opacity(showsFront ? 1 : 0)
                .animation(faceSwap, value: showsFront)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : (showsFront ? 0 : -180)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }
        .frame(width: 290, height: 370)
        .contentShape(Rectangle())
        // Once it's turned, taps on the card turn the page like anywhere else.
        .gesture(TapGesture().onEnded { flip() }, including: isFlipped ? .subviews : .all)
    }

    private var faceSwap: Animation {
        reduceMotion ? .easeInOut(duration: 0.35) : .linear(duration: 0.01).delay(Self.flipDuration / 2)
    }

    private func flip() {
        guard !isFlipped else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.35) : .easeInOut(duration: Self.flipDuration)) {
            isFlipped = true
        }
        confetti += 1
    }

    /// The numbers behind the persona, in a sentence.
    private var reason: String {
        switch wrapped.persona {
        case .loyalist:
            guard let favorite = wrapped.favorite, wrapped.itemCount > 0 else { return wrapped.persona.tagline }
            let fraction = Double(favorite.count) / Double(wrapped.itemCount)
            return "\(favorite.name) was \(WrappedFormat.percent(fraction)) of everything you bought."
        case .nightOwl:
            return "\(WrappedFormat.percent(wrapped.share(ofHours: 17...23))) of your purchases came after 5 PM."
        case .earlyBird:
            return "\(WrappedFormat.percent(wrapped.share(ofHours: 0...9))) of your purchases came before 10 AM."
        case .regular:
            let soFar = wrapped.period.isComplete ? "" : " so far"
            return "\(WrappedFormat.count(wrapped.dayCount, "day")) at the cafe\(soFar): at least every other school day."
        case .explorer:
            return "You tried \(wrapped.distinctItemCount) different things."
        case .dropIn:
            return "\(WrappedFormat.count(wrapped.purchaseCount, "purchase")), no set routine. You keep it fresh."
        }
    }
}

/// The revealed side: the persona's emoji, title and tagline, edged in foil.
private struct PersonaCardFront: View {
    let persona: CafePersona

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        VStack(spacing: 16) {
            Text(persona.emoji)
                .font(.system(size: 96))
            Text(persona.title)
                .font(WrappedStyle.title(28))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(persona.tagline)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Faint enough that the tagline keeps 4.5:1 at its brightest corner.
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: shape
        )
        .overlay { shape.strokeBorder(WrappedFX.foilGradient, lineWidth: 4) }
    }
}

/// The side you see first: plain foil, shimmering until it turns, and a question mark.
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
        .background(WrappedFX.foilGradient, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .foilShimmer(isActive: isShimmering)
    }
}

#Preview {
    PersonaPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x9D174D))
}
