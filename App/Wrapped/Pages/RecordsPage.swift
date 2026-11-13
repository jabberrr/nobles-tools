import SwiftUI
import NoblesKit

/// Personal bests, set as type between hairlines: the longest streak as the headline figure with
/// a flame for each day (and how it ranks among Nobles students, once that's known), then how
/// many different things you tried beside your biggest day, then your biggest purchase and your
/// first (unless that was the biggest). Each row slides in after the one before; any with nothing
/// to show is left out.
struct RecordsPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool
    /// How the streak ranks among other students'. It's fetched while the story is open, so it can
    /// arrive with the page on screen; it then rises in under the streak.
    var standing: StreakStanding? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the page last turned active, so a standing that arrives later rises in at once rather
    /// than waiting for its turn.
    @State private var activeSince: Date? = nil

    private enum Row: Hashable {
        case streak(CafeWrapped.Streak)
        /// Two short records side by side; at least one is set.
        case tallies(variety: Int?, biggestDay: CafeWrapped.Day?)
        case biggestPurchase(StoreCharge)
        case firstPurchase(StoreCharge)
    }

    var body: some View {
        // Spaced to fit every record, and the standing, on a 375 × 667 pt iPhone.
        VStack(alignment: .leading, spacing: 0) {
            WrappedEyebrow("Records", symbol: "trophy.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Personal bests")
                .font(WrappedStyle.title(30))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 8)
                .wrappedReveal(isActive, delay: 0.25)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element) { position, row in
                    let delay = 0.6 + 0.4 * Double(position)
                    if position > 0 {
                        WrappedRule()
                            .padding(.vertical, 12)
                            .wrappedReveal(isActive, delay: delay - 0.1, style: .growRight)
                    }
                    view(for: row, delay: delay)
                }
            }
            .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // A standing that arrives late moves the rows under it smoothly.
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: standing)
        .onChange(of: isActive, initial: true) { _, active in
            activeSince = active ? Date.now : nil
        }
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
    private func view(for row: Row, delay: Double) -> some View {
        switch row {
        case .streak(let streak):
            StreakRecord(streak: streak, standing: standing, isActive: isActive, delay: delay, standingDelay: standingDelay(after: delay))
        case .tallies(let variety, let biggestDay):
            tallies(variety: variety, biggestDay: biggestDay, delay: delay)
        case .biggestPurchase(let charge):
            PurchaseRecord(label: "Biggest purchase", charge: charge, showsPrice: true)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        case .firstPurchase(let charge):
            PurchaseRecord(label: "First purchase", charge: charge, showsPrice: false)
                .wrappedReveal(isActive, delay: delay, style: .slide(.trailing))
        }
    }

    /// The standing's turn, after the streak's flames; or right away once that turn has passed.
    private func standingDelay(after streakDelay: Double) -> Double {
        let turn = streakDelay + 1.1
        guard let activeSince else { return turn }
        return max(0.1, turn - Date.now.timeIntervalSince(activeSince))
    }

    /// Things tried and the biggest day, in two columns split by a hairline.
    private func tallies(variety: Int?, biggestDay: CafeWrapped.Day?, delay: Double) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let variety {
                WrappedStat(label: "Things tried") {
                    CountingText(Double(variety), isActive: isActive, duration: 1, delay: delay + 0.2, format: WrappedFormat.whole)
                }
                .wrappedReveal(isActive, delay: delay, style: .slide(.leading))
            }
            if let biggestDay {
                if variety != nil {
                    WrappedRule(axis: .vertical)
                        .wrappedReveal(isActive, delay: delay + 0.1, style: .fade)
                }
                // Two lines rather than one joined with "·".
                let caption = "\(WrappedFormat.day(biggestDay.date))\n\(WrappedFormat.count(biggestDay.itemCount, "item"))"
                WrappedStat(label: "Biggest day", caption: caption) {
                    CountingText(WrappedFormat.double(biggestDay.total), isActive: isActive, duration: 1, delay: delay + 0.35, format: WrappedFormat.dollars)
                }
                .wrappedReveal(isActive, delay: delay + 0.15, style: .slide(.trailing))
            }
        }
        // The hairline as tall as the taller column.
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The longest run of purchase days as the page's headline figure, counting up beside a block of
/// flames that pop in one per day, with its dates under it and then its standing, if any.
private struct StreakRecord: View {
    let streak: CafeWrapped.Streak
    let standing: StreakStanding?
    let isActive: Bool
    let delay: Double
    let standingDelay: Double

    /// The most flames drawn; longer streaks add "+N".
    private static let flameLimit = 10
    private static let flamesPerRow = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                WrappedLabel("Days in a row")
                HStack(spacing: 14) {
                    CountingText(Double(streak.length), isActive: isActive, duration: 0.9, delay: delay + 0.2, format: WrappedFormat.whole)
                        .font(WrappedStyle.number(60))
                        .monospacedDigit()
                        .foregroundStyle(WrappedStyle.highlight)
                        .lineLimit(1)
                    flames
                }
                Text(WrappedFormat.streakDates(streak))
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
            }
            // Full width, so the label isn't scaled down to the figure's width.
            .frame(maxWidth: .infinity, alignment: .leading)
            .wrappedReveal(isActive, delay: delay, style: .slide(.leading))
            if let standing {
                // Revealed on its own, so one that arrives late still rises in.
                StandingLine(standing: standing)
                    .padding(.top, 6)
                    .wrappedReveal(isActive, delay: standingDelay)
            }
        }
    }

    /// Up to `flameLimit` flames in rows of `flamesPerRow`, then "+N" for the rest.
    private var flames: some View {
        let count = min(streak.length, Self.flameLimit)
        let rowStarts = Array(stride(from: 0, to: count, by: Self.flamesPerRow))
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(rowStarts, id: \.self) { start in
                HStack(spacing: 3) {
                    ForEach(start..<min(start + Self.flamesPerRow, count), id: \.self) { flame in
                        Text("🔥")
                            .font(WrappedStyle.emoji(20))
                            .wrappedReveal(isActive, delay: flameDelay(flame), style: .pop)
                    }
                    if start == rowStarts.last, streak.length > Self.flameLimit {
                        Text("+\(streak.length - Self.flameLimit)")
                            .font(WrappedStyle.strongCaption)
                            .padding(.leading, 4)
                            .wrappedReveal(isActive, delay: flameDelay(Self.flameLimit), style: .pop)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func flameDelay(_ flame: Int) -> Double {
        delay + 0.4 + 0.07 * Double(flame)
    }
}

/// How the streak ranks among Nobles students: "Top 12%" beside "of Nobles students".
private struct StandingLine: View {
    let standing: StreakStanding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Top \(standing.topPercent)%")
                .font(WrappedStyle.number(22))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
            Text("of Nobles students")
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A purchase on record: its picture, its label over its name and when, and its price when that's
/// the record.
private struct PurchaseRecord: View {
    let label: String
    let charge: StoreCharge
    let showsPrice: Bool

    var body: some View {
        HStack(spacing: 14) {
            WrappedItemPicture(itemNamed: charge.detail, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                WrappedLabel(label)
                Text(name)
                    .font(WrappedStyle.itemName)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(WrappedFormat.moment(charge.madeAt))
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Takes the row's spare width, so neither the label nor the time is squeezed.
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsPrice {
                Text(charge.total.usd())
                    .font(WrappedStyle.number(24))
                    .monospacedDigit()
                    .foregroundStyle(WrappedStyle.highlight)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
    }

    /// "Jumbo Chocolate Chip Cookie", or "2 × Jumbo Chocolate Chip Cookie".
    private var name: String {
        charge.quantity > 1 ? "\(charge.quantity) × \(charge.detail)" : charge.detail
    }
}

#Preview {
    RecordsPage(wrapped: .sample, isActive: true, standing: .sample)
        .foregroundStyle(.white)
        .background(Color(hex: 0x0F6B63))
}
