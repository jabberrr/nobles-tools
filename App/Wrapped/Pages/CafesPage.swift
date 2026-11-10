import SwiftUI
import NoblesKit

/// Where the money went: a card per cafe, sliding in one after another, biggest first.
struct CafesPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    /// The most cafes with a card; the rest are counted underneath.
    private static let cardLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WrappedEyebrow("Your cafes", symbol: "cup.and.saucer.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text(wrapped.cafes.count == 1 ? "Your spot" : "Where you went")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
            ForEach(Array(cards.enumerated()), id: \.element.id) { rank, cafe in
                CafeCard(cafe: cafe, isTop: rank == 0, isActive: isActive, delay: cardDelay(rank))
            }
            if wrapped.cafes.count > Self.cardLimit {
                Text("+ \(wrapped.cafes.count - Self.cardLimit) more")
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .wrappedReveal(isActive, delay: cardDelay(cards.count))
            }
            Spacer(minLength: 8)
            Text(footnote)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isActive, delay: cardDelay(cards.count) + 0.4)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var cards: [CafeWrapped.Cafe] {
        Array(wrapped.cafes.prefix(Self.cardLimit))
    }

    private func cardDelay(_ rank: Int) -> Double {
        0.6 + 0.5 * Double(rank)
    }

    private var footnote: String {
        guard let top = wrapped.cafes.first else { return "" }
        if wrapped.cafes.count == 1 {
            return "All \(WrappedFormat.count(wrapped.purchaseCount, "purchase")), one spot. That's loyalty."
        }
        return "\(top.name) got \(WrappedFormat.percent(top.share)) of your cafe money."
    }
}

/// One cafe: what you spent there (counting up), its share of the total, and your go-to item.
private struct CafeCard: View {
    let cafe: CafeWrapped.Cafe
    let isTop: Bool
    let isActive: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(cafe.name)
                    .font(WrappedStyle.lead)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                CountingText(WrappedFormat.double(cafe.total), isActive: isActive, duration: 1.2, delay: delay + 0.2, format: WrappedFormat.dollars)
                    .font(WrappedStyle.number(26))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(isTop ? WrappedStyle.highlight : Color.white)
                    .layoutPriority(1)
            }
            ShareBar(share: cafe.share, isHighlighted: isTop, isActive: isActive, delay: delay + 0.35)
            HStack {
                Text("\(WrappedFormat.percent(cafe.share)) of your spending")
                Spacer(minLength: 8)
                Text(WrappedFormat.count(cafe.purchaseCount, "purchase"))
            }
            .font(WrappedStyle.caption)
            .foregroundStyle(WrappedStyle.secondary)
            if let item = cafe.topItem {
                Text("Go-to: \(item.emoji) \(item.name)")
                    .font(WrappedStyle.caption.weight(.bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .wrappedCard()
        .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
    }
}

/// A cafe's share of the total, as a bar that grows in from the left.
private struct ShareBar: View {
    let share: Double
    let isHighlighted: Bool
    let isActive: Bool
    let delay: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(isHighlighted ? WrappedStyle.highlight : Color.white)
                    .frame(width: max(proxy.size.height, proxy.size.width * CGFloat(min(max(share, 0), 1))))
                    .wrappedReveal(isActive, delay: delay, style: .growRight)
            }
        }
        .frame(height: 10)
    }
}

#Preview {
    CafesPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0xB42318))
}
