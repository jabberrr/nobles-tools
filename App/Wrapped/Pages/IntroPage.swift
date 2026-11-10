import SwiftUI
import NoblesKit

/// The cover: "Cafe Wrapped" in foil over a drift of the semester's favorite foods, leaving out
/// the #1 so its page is still a surprise.
struct IntroPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

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
                Text(Self.subtitle(for: wrapped))
                    .font(WrappedStyle.body)
                    .foregroundStyle(WrappedStyle.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive, delay: 0.8)
                Spacer()
                WrappedHint("Tap to start")
                    .wrappedReveal(isActive, delay: 1.4, style: .fade)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.bottom, 28)
        }
    }

    /// The line under the title, which VoiceOver reads too.
    nonisolated static func subtitle(for wrapped: CafeWrapped) -> String {
        wrapped.period.isComplete
            ? "What you bought at the cafes this semester."
            : "What you've bought at the cafes so far."
    }

    /// Foods from the cafes' menus, to fill out the drift.
    private static let staples = ["🍪", "🥐", "🍩", "🧁", "🍕", "🥤", "🍫", "🍌"]

    /// The top items' emoji after #1, then the staples, without repeats or #1's emoji.
    private var emojis: [String] {
        let favorite = wrapped.favorite?.emoji
        var emojis: [String] = []
        for emoji in wrapped.topItems.dropFirst().map(\.emoji) + Self.staples where emoji != favorite && !emojis.contains(emoji) {
            emojis.append(emoji)
        }
        return emojis
    }
}

#Preview {
    IntroPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x2A0A5E))
}
