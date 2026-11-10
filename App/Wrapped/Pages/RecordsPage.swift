import SwiftUI
import NoblesKit

/// Personal bests: the longest streak, how many different things you tried, the priciest buy and
/// the semester's first (unless that was the priciest). Each card slides in after the one before;
/// any with nothing to show is left out.
struct RecordsPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    private enum Record: Hashable {
        case streak(CafeWrapped.Streak)
        case variety(Int)
        case biggest(StoreCharge)
        case first(StoreCharge)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WrappedEyebrow("Records", symbol: "trophy.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Personal bests")
                .font(WrappedStyle.title(32))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
                .padding(.bottom, 4)
            ForEach(Array(records.enumerated()), id: \.element) { position, record in
                card(for: record, delay: 0.6 + 0.45 * Double(position))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var records: [Record] {
        var records: [Record] = []
        if let streak = wrapped.longestStreak, streak.length > 1 {
            records.append(.streak(streak))
        }
        if wrapped.distinctItemCount > 1 {
            records.append(.variety(wrapped.distinctItemCount))
        }
        if let charge = wrapped.biggestPurchase {
            records.append(.biggest(charge))
        }
        if let charge = wrapped.firstPurchase, charge.id != wrapped.biggestPurchase?.id {
            records.append(.first(charge))
        }
        return records
    }

    @ViewBuilder
    private func card(for record: Record, delay: Double) -> some View {
        switch record {
        case .streak(let streak):
            StreakCard(streak: streak, isActive: isActive, delay: delay)
        case .variety(let count):
            VarietyCard(count: count, isActive: isActive, delay: delay)
        case .biggest(let charge):
            ChargeCard(title: "Biggest single buy", charge: charge, detail: WrappedFormat.moment(charge.madeAt), showsPrice: true)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        case .first(let charge):
            ChargeCard(title: "First of the semester", charge: charge, detail: WrappedFormat.moment(charge.madeAt), showsPrice: false)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CountingText(Double(streak.length), isActive: isActive, duration: 0.9, delay: delay + 0.2, format: WrappedFormat.whole)
                    .font(WrappedStyle.number(42))
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.highlight)
                Text("days in a row")
                    .font(WrappedStyle.lead)
            }
            HStack(spacing: 3) {
                ForEach(0..<min(streak.length, Self.flameLimit), id: \.self) { flame in
                    Text("🔥")
                        .font(.system(size: 22))
                        .wrappedReveal(isActive, delay: delay + 0.4 + 0.07 * Double(flame), style: .pop)
                }
                if streak.length > Self.flameLimit {
                    Text("+\(streak.length - Self.flameLimit)")
                        .font(WrappedStyle.caption.weight(.heavy))
                        .padding(.leading, 4)
                        .wrappedReveal(isActive, delay: delay + 0.4 + 0.07 * Double(Self.flameLimit), style: .pop)
                }
            }
            .accessibilityHidden(true)
            Text(dates)
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wrappedCard()
        .wrappedReveal(isActive, delay: delay, style: .slide(.leading))
    }

    /// "Oct 5 – Oct 16", noting any days off the run skipped: only a missed school day ends it.
    private var dates: String {
        let span = "\(WrappedFormat.shortDay(streak.start)) – \(WrappedFormat.shortDay(streak.end))"
        let days = streak.start.days(until: streak.end) + 1
        guard days > streak.length else { return span }
        let spansWeekend = (0..<days).contains { streak.start.adding(days: $0).isWeekend }
        return "\(span) · \(spansWeekend ? "Weekends" : "Holidays") off"
    }
}

/// How many different things you tried.
private struct VarietyCard: View {
    let count: Int
    let isActive: Bool
    let delay: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            CountingText(Double(count), isActive: isActive, duration: 1, delay: delay + 0.2, format: WrappedFormat.whole)
                .font(WrappedStyle.number(36))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
            Text("different things tried")
                .font(WrappedStyle.lead)
                .fixedSize(horizontal: false, vertical: true)
        }
        .wrappedCard()
        .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
    }
}

/// A single purchase on record: its picture, name and when, with its price if it's the point.
private struct ChargeCard: View {
    let title: String
    let charge: StoreCharge
    let detail: String
    let showsPrice: Bool

    var body: some View {
        HStack(spacing: 12) {
            WrappedItemPicture(emoji: CafeItemArt.emoji(for: charge.detail), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(WrappedStyle.secondary)
                Text(itemName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if showsPrice {
                Text(charge.total.usd())
                    .font(WrappedStyle.number(24))
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.highlight)
                    .layoutPriority(1)
            }
        }
        .wrappedCard(padding: 10)
    }

    /// "Chocolate Chip Cookie", or "2 × Chocolate Chip Cookie".
    private var itemName: String {
        charge.quantity > 1 ? "\(charge.quantity) × \(charge.detail)" : charge.detail
    }
}

#Preview {
    RecordsPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x0F6B63))
}
