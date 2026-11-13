import SwiftUI
import NoblesKit

/// The countdown: the top items revealed from the bottom up, each set as type beside a big rank
/// numeral, with #1 last and still under foil for the next page.
struct TopItemsPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WrappedEyebrow("Your top \(wrapped.topItems.count)", symbol: "list.number")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Most ordered")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 10)
                .wrappedReveal(isActive, delay: 0.25)
            VStack(spacing: 0) {
                ForEach(Array(wrapped.topItems.enumerated()), id: \.element.id) { offset, item in
                    let rank = offset + 1
                    VStack(spacing: 0) {
                        if rank > 1 {
                            WrappedRule()
                        }
                        Group {
                            if rank == 1 {
                                HiddenItemRow()
                            } else {
                                TopItemRow(rank: rank, item: item)
                            }
                        }
                        // Rows open up on taller screens.
                        .frame(minHeight: 72, maxHeight: 100)
                    }
                    .wrappedReveal(isActive, delay: delay(forRank: rank), style: rank == 1 ? .pop : .slide(.leading))
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The lowest rank shows first and #1 last, a beat after #2.
    private func delay(forRank rank: Int) -> Double {
        let steps = wrapped.topItems.count - rank
        return 0.6 + 0.4 * Double(steps) + (rank == 1 ? 0.3 : 0)
    }
}

/// A ranked item: its rank, its picture, its name, and how many there were over what they cost
/// in all.
private struct TopItemRow: View {
    let rank: Int
    let item: CafeWrapped.Item

    var body: some View {
        HStack(spacing: 12) {
            RankNumeral(rank: rank)
            WrappedItemPicture(item: item, size: TopItemsLayout.pictureSize)
            Text(item.name)
                .font(WrappedStyle.itemName)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("×\(item.count)")
                    .font(WrappedStyle.number(24))
                    .monospacedDigit()
                Text(item.total.usd())
                    .font(WrappedStyle.caption)
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.secondary)
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }
}

/// #1, still under foil for the next page: its rank in the highlight color, then foil where its
/// picture, name and count would be, with a "?" pressed into the picture's disc.
private struct HiddenItemRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RankNumeral(rank: 1)
            FoilSurface(cornerRadius: TopItemsLayout.pictureSize / 2) {
                FoilStamp("?", size: TopItemsLayout.pictureSize * 0.55)
            }
            .frame(width: TopItemsLayout.pictureSize, height: TopItemsLayout.pictureSize)
            .shadow(color: .black.opacity(0.3), radius: 4.5, y: 2)
            FoilSurface(cornerRadius: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 20)
            FoilSurface(cornerRadius: 6)
                .frame(width: 52, height: 26)
        }
    }
}

/// The rank at the start of a row: oversized, on the page's left edge, #1 in the highlight color.
private struct RankNumeral: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(WrappedStyle.number(52))
            .foregroundStyle(rank == 1 ? WrappedStyle.highlight : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 40, alignment: .leading)
    }
}

/// Sizes the rows share, so the hidden #1 lines up with the rest.
private enum TopItemsLayout {
    static let pictureSize: CGFloat = 56
}

#Preview {
    TopItemsPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0xA3145A))
}
