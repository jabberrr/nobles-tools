import SwiftUI
import NoblesKit

/// The cover: "Cafe Wrapped" in foil over a drift of the semester's favorite foods.
struct IntroPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            FloatingEmoji(emojis)
            VStack(spacing: 20) {
                Spacer()
                WrappedEyebrow(WrappedFormat.period(wrapped.period), symbol: "gift.fill")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Text("Cafe\nWrapped")
                    .font(WrappedStyle.title(64))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(WrappedFX.foilGradient)
                    .foilShimmer(isActive: isActive)
                    .wrappedReveal(isActive, delay: 0.3, style: .pop)
                Text(subtitle)
                    .font(WrappedStyle.body)
                    .foregroundStyle(WrappedStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive, delay: 0.8)
                Spacer()
                hint
                    .wrappedReveal(isActive, delay: 1.4, style: .fade)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.bottom, 28)
        }
    }

    private var subtitle: String {
        wrapped.period.isComplete
            ? "Everything you grabbed at the cafes this semester, unwrapped."
            : "Everything you've grabbed at the cafes this semester so far, unwrapped."
    }

    /// The top items' emoji first, then some cafe staples, without repeats.
    private var emojis: [String] {
        var emojis: [String] = []
        for emoji in wrapped.topItems.map(\.emoji) + ["☕️", "🍪", "🥯", "🧁", "🥤", "🍩"] where !emojis.contains(emoji) {
            emojis.append(emoji)
        }
        return emojis
    }

    @ViewBuilder
    private var hint: some View {
        let label = Label("Tap to unwrap your semester", systemImage: "hand.tap.fill")
            .font(WrappedStyle.caption)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.16), in: Capsule())
        if isStatic || reduceMotion {
            label
        } else {
            label.phaseAnimator([false, true]) { content, isDimmed in
                content
                    .opacity(isDimmed ? 0.55 : 1)
                    .scaleEffect(isDimmed ? 0.97 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        }
    }
}

#Preview {
    IntroPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x2A0A5E))
}
