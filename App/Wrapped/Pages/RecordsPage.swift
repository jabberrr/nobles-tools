import SwiftUI
import NoblesKit

/// Personal bests: the longest streak, how many different things you tried beside your biggest
/// day, then your biggest purchase and your first (unless that was the biggest). Each row slides
/// in after the one before; any with nothing to show is left out.
struct RecordsPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    private enum Row: Hashable {
        case streak(CafeWrapped.Streak)
        /// Two short records side by side; at least one is set.
        case tallies(variety: Int?, biggestDay: CafeWrapped.Day?)
        case biggestPurchase(StoreCharge)
        case firstPurchase(StoreCharge)
    }

    var body: some View {
        // Spaced to fit every record on a 375 × 667 pt iPhone.
        VStack(alignment: .leading, spacing: 8) {
            WrappedEyebrow("Records", symbol: "trophy.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Personal bests")
                .font(WrappedStyle.title(30))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
                .padding(.bottom, 4)
            ForEach(Array(rows.enumerated()), id: \.element) { position, row in
                card(for: row, delay: 0.6 + 0.4 * Double(position))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var rows: [Row] {
        var rows: [Row] = []
        if let streak = wrapped.longestStreak, streak.length > 1 {
            rows.append(.streak(streak))
        }
        let variety = wrapped.distinctItemCount > 1 ? wrapped.distinctItemCount : nil
        // On a single day, the biggest day is the whole recap.
        let biggestDay = wrapped.dayCount > 1 ? wrapped.biggestDay : nil
        if variety != nil || biggestDay != nil {
            rows.append(.tallies(variety: variety, biggestDay: biggestDay))
        }
        if let charge = wrapped.biggestPurchase {
            rows.append(.biggestPurchase(charge))
        }
        if let charge = wrapped.firstPurchase, charge.id != wrapped.biggestPurchase?.id {
            rows.append(.firstPurchase(charge))
        }
        return rows
    }

    @ViewBuilder
    private func card(for row: Row, delay: Double) -> some View {
        switch row {
        case .streak(let streak):
            StreakCard(streak: streak, isActive: isActive, delay: delay)
        case .tallies(let variety, let biggestDay):
            HStack(spacing: 10) {
                if let variety {
                    varietyTile(variety, delay: delay)
                }
                if let biggestDay {
                    biggestDayTile(biggestDay, delay: delay + 0.15)
                }
            }
            // Both tiles as tall as the taller one.
            .fixedSize(horizontal: false, vertical: true)
        case .biggestPurchase(let charge):
            ChargeCard(title: "Biggest purchase", charge: charge, showsPrice: true)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        case .firstPurchase(let charge):
            ChargeCard(title: "First purchase", charge: charge, showsPrice: false)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        }
    }

    private func varietyTile(_ count: Int, delay: Double) -> some View {
        RecordTile(title: "You tried", caption: "different things") {
            CountingText(Double(count), isActive: isActive, duration: 1, delay: delay + 0.2, format: WrappedFormat.whole)
        }
        .wrappedReveal(isActive, delay: delay, style: .slide(.leading))
    }

    private func biggestDayTile(_ day: CafeWrapped.Day, delay: Double) -> some View {
        let caption = "\(WrappedFormat.shortDay(day.date)) · \(WrappedFormat.count(day.itemCount, "item"))"
        return RecordTile(title: "Biggest day", caption: caption) {
            CountingText(WrappedFormat.double(day.total), isActive: isActive, duration: 1, delay: delay + 0.2, format: WrappedFormat.dollars)
        }
        .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
    }
}

/// The longest run of purchase days, counting up, with a flame popping in for each day.
private struct StreakCard: View {
    let streak: CafeWrapped.Streak
    let isActive: Bool
    let delay: Double

    /// The most flames drawn; longer streaks add "+N".
    private static let flameLimit = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CountingText(Double(streak.length), isActive: isActive, duration: 0.9, delay: delay + 0.2, format: WrappedFormat.whole)
                    .font(WrappedStyle.number(36))
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.highlight)
                Text("days in a row")
                    .font(WrappedStyle.lead)
            }
            HStack(spacing: 3) {
                ForEach(0..<min(streak.length, Self.flameLimit), id: \.self) { flame in
                    Text("🔥")
                        .font(WrappedStyle.emoji(18))
                        .wrappedReveal(isActive, delay: delay + 0.4 + 0.07 * Double(flame), style: .pop)
                }
                if streak.length > Self.flameLimit {
                    Text("+\(streak.length - Self.flameLimit)")
                        .font(WrappedStyle.strongCaption)
                        .padding(.leading, 4)
                        .wrappedReveal(isActive, delay: delay + 0.4 + 0.07 * Double(Self.flameLimit), style: .pop)
                }
            }
            .accessibilityHidden(true)
            Text(WrappedFormat.streakDates(streak))
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wrappedCard(padding: 14)
        .wrappedReveal(isActive, delay: delay, style: .slide(.leading))
    }
}

/// A short record on a card that shares its row: a label, a figure and a caption.
private struct RecordTile<Figure: View>: View {
    let title: String
    let caption: String
    @ViewBuilder let figure: Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedCardLabel(title)
            figure
                .font(WrappedStyle.number(26))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .wrappedCard(padding: 14)
    }
}

/// A single purchase on record: its picture, name and when, with its price if it's the point.
private struct ChargeCard: View {
    let title: String
    let charge: StoreCharge
    let showsPrice: Bool

    var body: some View {
        HStack(spacing: 12) {
            WrappedItemPicture(itemNamed: charge.detail, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                WrappedCardLabel(title)
                Text(name)
                    .font(WrappedStyle.itemName)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(WrappedFormat.moment(charge.madeAt))
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if showsPrice {
                Text(charge.total.usd())
                    .font(WrappedStyle.number(20))
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.highlight)
                    .layoutPriority(1)
            }
        }
        .wrappedCard(padding: 12)
    }

    /// "Jumbo Chocolate Chip Cookie", or "2 × Jumbo Chocolate Chip Cookie".
    private var name: String {
        charge.quantity > 1 ? "\(charge.quantity) × \(charge.detail)" : charge.detail
    }
}

#Preview {
    RecordsPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x0F6B63))
}
