import SwiftUI
import NoblesKit

/// The countdown: the top items revealed from the bottom up, with #1 kept under foil for the
/// next page.
struct TopItemsPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WrappedEyebrow("Your top \(wrapped.topItems.count)", symbol: "list.number")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Most ordered")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
                .padding(.bottom, 4)
            NumberOneTeaser()
                .wrappedReveal(isActive, delay: delay(forRank: 1), style: .pop)
            ForEach(Array(wrapped.topItems.enumerated().dropFirst()), id: \.element.id) { offset, item in
                TopItemRow(rank: offset + 1, item: item)
                    .wrappedReveal(isActive, delay: delay(forRank: offset + 1), style: .slide(.leading))
            }
            Spacer(minLength: 8)
            Text("Your #1 is next.")
                .font(WrappedStyle.lead)
                .foregroundStyle(WrappedStyle.secondary)
                .wrappedReveal(isActive, delay: delay(forRank: 1) + 0.5)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The lowest rank shows first and #1's teaser last, a beat after #2.
    private func delay(forRank rank: Int) -> Double {
        let steps = wrapped.topItems.count - rank
        return 0.6 + 0.4 * Double(steps) + (rank == 1 ? 0.3 : 0)
    }
}

/// A ranked item: its picture, name, what it cost in all and how many you got.
private struct TopItemRow: View {
    let rank: Int
    let item: CafeWrapped.Item

    var body: some View {
        HStack(spacing: 12) {
            RankNumber(rank: rank)
            WrappedItemPicture(item: item, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(WrappedStyle.itemName)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(item.total.usd()) in all")
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
            }
            Spacer(minLength: 4)
            Text("×\(item.count)")
                .font(WrappedStyle.number(22))
                .monospacedDigit()
                .layoutPriority(1)
        }
        .wrappedCard(padding: 10, cornerRadius: 18)
    }
}

/// #1, still hidden: a strip of crinkled foil, lightly washed, with "? ? ?" and a gift set on
/// white so they read over its darkest creases.
private struct NumberOneTeaser: View {
    private static let cornerRadius: CGFloat = 16
    private static let chipHeight: CGFloat = 38

    var body: some View {
        HStack(spacing: 12) {
            RankNumber(rank: 1)
            HStack {
                Text("? ? ?")
                    .font(WrappedStyle.number(22))
                    .padding(.horizontal, 14)
                    .frame(height: Self.chipHeight)
                    .background(Color.white.opacity(0.85), in: Capsule())
                Spacer()
                Image(systemName: "gift.fill")
                    .font(WrappedStyle.symbol(17))
                    .frame(width: Self.chipHeight, height: Self.chipHeight)
                    .background(Color.white.opacity(0.85), in: Circle())
            }
            .foregroundStyle(WrappedStyle.ink)
            .padding(.horizontal, 12)
            .frame(height: 62)
            .background {
                FoilSurface(cornerRadius: Self.cornerRadius)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.3))
                    }
            }
        }
        .padding(.horizontal, 10)
    }
}

/// The rank at the start of a row, in a fixed width so the rows line up.
private struct RankNumber: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(WrappedStyle.number(24))
            .frame(width: 28)
    }
}

#Preview {
    TopItemsPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0xA3145A))
}
