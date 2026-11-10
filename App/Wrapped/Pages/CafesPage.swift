import SwiftUI
import NoblesKit

/// Where the money went: a card per cafe, sliding in one after another, biggest first, each with
/// what you got there most. The overall #1 stays under foil wherever it shows up, for its own page.
struct CafesPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    /// The most cafes with a card; the rest are counted underneath.
    private static let cardLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WrappedEyebrow("Your cafes", symbol: "cup.and.saucer.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text(wrapped.cafes.count == 1 ? "Your cafe" : "Where you went")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
            ForEach(Array(cards.enumerated()), id: \.element.id) { rank, cafe in
                CafeCard(
                    cafe: cafe,
                    itemLimit: itemLimit,
                    hiddenItemID: wrapped.favorite?.id,
                    isTop: rank == 0,
                    isActive: isActive,
                    delay: cardDelay(rank)
                )
            }
            if wrapped.cafes.count > Self.cardLimit {
                Text("+\(wrapped.cafes.count - Self.cardLimit) more")
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

    /// Items listed on each card: a cafe's top three while up to two cards share the page, which
    /// still fits a 375 × 667 pt iPhone; only its top one when three do.
    private var itemLimit: Int {
        cards.count > 2 ? 1 : 3
    }

    private func cardDelay(_ rank: Int) -> Double {
        0.6 + 0.5 * Double(rank)
    }

    private var footnote: String {
        guard let top = wrapped.cafes.first else { return "" }
        if wrapped.cafes.count == 1 {
            return wrapped.purchaseCount == 1
                ? "Your one purchase was at \(top.name)."
                : "All \(wrapped.purchaseCount.formatted()) purchases were at \(top.name)."
        }
        return "\(WrappedFormat.percent(top.share)) of your spending was at \(top.name)."
    }
}

/// One cafe: what you spent there (counting up), its share of the total, and what you got there
/// most, with the overall #1 (`hiddenItemID`) under foil.
private struct CafeCard: View {
    let cafe: CafeWrapped.Cafe
    let itemLimit: Int
    let hiddenItemID: CafeWrapped.Item.ID?
    let isTop: Bool
    let isActive: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            if !cafe.topItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cafe.topItems.prefix(itemLimit)) { item in
                        if item.id == hiddenItemID {
                            HiddenItemRow()
                        } else {
                            CafeItemRow(item: item)
                        }
                    }
                }
            }
        }
        .wrappedCard(padding: 14)
        .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
    }
}

/// One of a cafe's most-bought items, on a single line: its picture, its name and how many you got.
private struct CafeItemRow: View {
    let item: CafeWrapped.Item

    var body: some View {
        HStack(spacing: 8) {
            // A touch smaller than the name, so it doesn't make the row taller.
            WrappedItemArt(item: item, size: 13)
                .frame(width: 22, height: 18)
            Text(item.name)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 8)
            Text("×\(item.count.formatted())")
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.secondary)
                .layoutPriority(1)
        }
        .font(WrappedStyle.strongCaption)
    }
}

/// The overall #1 in a cafe's list: a strip of lightly washed foil with no name, picture or
/// count, so the favorite page is still a surprise. "? ? ?" and a gift sit on white, so they read
/// over the foil's creases.
private struct HiddenItemRow: View {
    private static let cornerRadius: CGFloat = 8
    private static let chipHeight: CGFloat = 18

    var body: some View {
        HStack(spacing: 8) {
            Text("? ? ?")
                .padding(.horizontal, 8)
                .frame(height: Self.chipHeight)
                .background(Color.white.opacity(0.85), in: Capsule())
            Spacer(minLength: 0)
            Image(systemName: "gift.fill")
                .font(WrappedStyle.symbol(10))
                .frame(width: Self.chipHeight, height: Self.chipHeight)
                .background(Color.white.opacity(0.85), in: Circle())
        }
        .font(WrappedStyle.strongCaption)
        .foregroundStyle(WrappedStyle.ink)
        .padding(.horizontal, 3)
        .frame(height: 24)
        .background {
            FoilSurface(cornerRadius: Self.cornerRadius)
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                }
        }
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
