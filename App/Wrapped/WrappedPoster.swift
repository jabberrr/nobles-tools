import SwiftUI
import UIKit
import NoblesKit

/// The shareable recap, shaped like a story (9:16) and set like a poster: the #1's plate hanging
/// off the top right corner beside the masthead and a giant "#1", the item's name under them, then
/// what the semester came to as the one big figure and the other headline stats two to a row,
/// with hairlines between. It's shared as an image, so it reads on its own.
struct WrappedPoster: View {
    static let size = CGSize(width: 360, height: 640)

    let wrapped: CafeWrapped
    /// 0 for the shared image, which apps crop themselves.
    var cornerRadius: CGFloat = 32

    private static let margin: CGFloat = 24
    private static let plateSize: CGFloat = 220
    /// How far the plate hangs off the poster's right and top edges.
    private static let plateOverhang = CGSize(width: 40, height: 36)
    /// The masthead's width: the poster's top left, clear of the plate.
    private static var mastheadWidth: CGFloat {
        size.width - plateSize + plateOverhang.width - margin - 8
    }

    private struct Stat: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            if let item = wrapped.favorite {
                favorite(item)
            }
            WrappedRule()
                .padding(.vertical, 11)
            WrappedStat(label: "Spent", caption: WrappedFormat.count(wrapped.purchaseCount, "purchase"), size: 44) {
                Text(wrapped.total.usd())
            }
            ForEach(Array(statRows.enumerated()), id: \.offset) { _, row in
                WrappedRule()
                    .padding(.vertical, 11)
                HStack(alignment: .top, spacing: 16) {
                    ForEach(row) { stat in
                        statView(stat)
                    }
                }
            }
            Spacer(minLength: 10)
            footer
        }
        .padding(Self.margin)
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(.white)
        .background(alignment: .topTrailing) { plate }
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// "CAFE WRAPPED" over the semester, then a giant "#1" when there's a favorite.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CAFE WRAPPED")
                .font(WrappedStyle.title(24))
                .foregroundStyle(WrappedFX.foilGradient)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(wrapped.period.name.uppercased())
                if !wrapped.period.isComplete {
                    Text("SO FAR")
                }
            }
            .font(WrappedStyle.eyebrow)
            .tracking(WrappedStyle.eyebrowTracking)
            .foregroundStyle(WrappedStyle.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.top, 6)
            if wrapped.favorite != nil {
                Text("#1")
                    .font(WrappedStyle.number(72))
                    .foregroundStyle(WrappedStyle.highlight)
                    .padding(.top, 8)
            }
        }
        .frame(width: Self.mastheadWidth, alignment: .leading)
    }

    /// The #1's picture, big, cut off by the poster's top right corner.
    @ViewBuilder
    private var plate: some View {
        if let item = wrapped.favorite {
            WrappedItemPicture(item: item, size: Self.plateSize)
                .offset(x: Self.plateOverhang.width, y: -Self.plateOverhang.height)
        }
    }

    private func favorite(_ item: CafeWrapped.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(WrappedStyle.hero(24))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text("Bought \(WrappedFormat.count(item.count, "time"))")
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
        }
    }

    private func statView(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedCardLabel(stat.label)
            Text(stat.value)
                .font(WrappedStyle.title(17))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The app's name, with the photo's credit beside it when the #1 shows an Open Food Facts
    /// product photo, as its license (CC BY-SA) asks of anything that shares it.
    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            WrappedCardLabel("Nobles Tools")
            if showsProductPhoto {
                Spacer(minLength: 0)
                Text("Photo: Open Food Facts, CC BY-SA")
                    .font(WrappedStyle.cardLabel)
                    .foregroundStyle(WrappedStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// Whether the #1 is drawn with a product photo: it's a branded item and the app has the photo
    /// (`WrappedItemArt` falls back to the emoji otherwise).
    private var showsProductPhoto: Bool {
        guard let name = wrapped.favorite?.productImage else { return false }
        return UIImage(named: name) != nil
    }

    /// The stats under the total, as many as the recap has.
    private var stats: [Stat] {
        var stats: [Stat] = []
        if let cafe = wrapped.cafes.first {
            stats.append(Stat(label: "Top cafe", value: cafe.name))
        }
        if let hour = wrapped.peakHour {
            stats.append(Stat(label: "Busiest hour", value: WrappedFormat.hour(hour)))
        }
        if let streak = wrapped.longestStreak, streak.length > 1 {
            stats.append(Stat(label: "Days in a row", value: streak.length.formatted()))
        }
        stats.append(Stat(label: "Cafe personality", value: "\(wrapped.persona.emoji) \(wrapped.persona.title)"))
        return stats
    }

    /// `stats` two to a row; an odd last one has its row to itself.
    private var statRows: [[Stat]] {
        let stats = self.stats
        return stride(from: 0, to: stats.count, by: 2).map { Array(stats[$0..<min($0 + 2, stats.count)]) }
    }

    private var backdrop: some View {
        let colors = WrappedPage.summary.colors
        return ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color(hex: 0xDB2777).opacity(0.45))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 140, y: -230)
            Circle()
                .fill(Color(hex: 0x7C3AED).opacity(0.5))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -150, y: 220)
        }
    }

    private var accessibilitySummary: String {
        var lines = ["My \(wrapped.period.name) Cafe Wrapped."]
        if let item = wrapped.favorite {
            lines.append("My number 1 is \(item.name), bought \(WrappedFormat.count(item.count, "time")).")
        }
        lines.append("Spent, \(wrapped.total.usd()), on \(WrappedFormat.count(wrapped.purchaseCount, "purchase")).")
        lines += stats.map { "\($0.label), \($0.value)." }
        return lines.joined(separator: " ")
    }
}

#Preview {
    WrappedPoster(wrapped: .sample)
}
