import SwiftUI
import UIKit
import NoblesKit

/// The shareable recap: the semester's headline stats on one poster, shaped like a story (9:16).
struct WrappedPoster: View {
    static let size = CGSize(width: 360, height: 640)

    let wrapped: CafeWrapped
    /// 0 for the shared image, which apps crop themselves.
    var cornerRadius: CGFloat = 32

    private struct Stat: Identifiable {
        let value: String
        let label: String
        var id: String { label }
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            if let item = wrapped.favorite {
                favorite(item)
            }
            statGrid
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(.white)
        .background { backdrop }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("CAFE WRAPPED")
                .font(WrappedStyle.title(20))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(WrappedFX.foilGradient)
            Spacer(minLength: 8)
            Text(WrappedFormat.period(wrapped.period).uppercased())
                .font(WrappedStyle.eyebrow)
                .tracking(WrappedStyle.eyebrowTracking)
                .foregroundStyle(WrappedStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func favorite(_ item: CafeWrapped.Item) -> some View {
        VStack(spacing: 6) {
            WrappedItemPicture(item: item, size: 118)
                .padding(.bottom, 6)
            Text("MY #1")
                .font(WrappedStyle.eyebrow)
                .tracking(WrappedStyle.eyebrowTracking)
                .foregroundStyle(WrappedStyle.highlight)
            Text(item.name)
                .font(WrappedStyle.hero(22))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(WrappedFormat.count(item.count, "time")) · \(item.total.usd())")
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
        }
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

    /// Two tiles to a row; an odd last tile takes the whole row.
    private var statGrid: some View {
        let stats = statList
        return VStack(spacing: 8) {
            ForEach(Array(stride(from: 0, to: stats.count, by: 2)), id: \.self) { start in
                HStack(spacing: 8) {
                    ForEach(stats[start..<min(start + 2, stats.count)]) { stat in
                        tile(stat)
                    }
                }
            }
        }
    }

    private func tile(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.value)
                .font(WrappedStyle.title(17))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            WrappedCardLabel(stat.label)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(WrappedStyle.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statList: [Stat] {
        var stats = [
            Stat(value: wrapped.total.usd(), label: "Spent"),
            Stat(value: wrapped.purchaseCount.formatted(), label: "Purchases"),
        ]
        if let cafe = wrapped.cafes.first {
            stats.append(Stat(value: cafe.name, label: "Top cafe"))
        }
        if let hour = wrapped.peakHour {
            stats.append(Stat(value: WrappedFormat.hour(hour), label: "Busiest hour"))
        }
        if let streak = wrapped.longestStreak, streak.length > 1 {
            stats.append(Stat(value: WrappedFormat.count(streak.length, "day"), label: "Longest streak"))
        }
        stats.append(Stat(value: "\(wrapped.persona.emoji) \(wrapped.persona.title)", label: "Cafe personality"))
        return stats
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
        let lines = statList.map { "\($0.label), \($0.value)." }
        let favorite = wrapped.favorite.map { "My number 1 is \($0.name), \(WrappedFormat.count($0.count, "time"))." }
        return (["My \(wrapped.period.name) Cafe Wrapped."] + [favorite].compactMap { $0 } + lines).joined(separator: " ")
    }
}

#Preview {
    WrappedPoster(wrapped: .sample)
}
