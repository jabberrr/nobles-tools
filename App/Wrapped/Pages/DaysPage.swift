import SwiftUI
import NoblesKit

/// Your week and your months: purchases by weekday with your busiest day lit up, then spending
/// month by month with the biggest month lit up.
struct DaysPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    /// `Calendar` weekdays from Monday to Sunday.
    private static let week = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WrappedEyebrow("Your week", symbol: "calendar")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            if let favorite = wrapped.favoriteWeekday {
                Text("\(WrappedFormat.weekday(favorite)) was your busiest day")
                    .font(WrappedStyle.title(30))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive, delay: 0.3)
            }
            Text(Self.visits(wrapped))
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isActive, delay: 0.6)
            Spacer(minLength: 12)
            WrappedBarChart(bars: weekdayBars, isActive: isActive, height: 120, delay: 0.9, stagger: 0.1)
            if wrapped.months.count > 1 {
                Spacer(minLength: 12)
                months
            }
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "You went on 42 different days."
    nonisolated static func visits(_ wrapped: CafeWrapped) -> String {
        wrapped.dayCount == 1
            ? "You went on one day."
            : "You went on \(wrapped.dayCount.formatted()) different days."
    }

    /// Monday to Friday, plus a weekend day only if you bought something on it.
    private var weekdayBars: [WrappedBarChart.Bar] {
        Self.week.compactMap { (weekday: Int) -> WrappedBarChart.Bar? in
            let count = wrapped.weekdayCounts.indices.contains(weekday - 1) ? wrapped.weekdayCounts[weekday - 1] : 0
            let isWeekend = weekday == 1 || weekday == 7
            guard !isWeekend || count > 0 else { return nil }
            return WrappedBarChart.Bar(
                id: weekday,
                value: Double(count),
                label: WrappedFormat.shortWeekday(weekday),
                valueLabel: count > 0 ? count.formatted() : nil,
                isHighlighted: weekday == wrapped.favoriteWeekday
            )
        }
    }

    private var months: some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedEyebrow("Month by month", symbol: "chart.bar.fill")
                .wrappedReveal(isActive, delay: 1.8, style: .fade)
            WrappedBarChart(bars: monthBars, isActive: isActive, height: 90, delay: 1.9, stagger: 0.14)
        }
    }

    /// One bar per month, its total over it; the biggest month highlighted.
    private var monthBars: [WrappedBarChart.Bar] {
        let biggest = wrapped.biggestMonth
        return wrapped.months.enumerated().map { position, month in
            WrappedBarChart.Bar(
                id: position,
                value: WrappedFormat.double(month.total),
                label: month.name,
                valueLabel: month.total.usd(showsCents: false),
                isHighlighted: month.id == biggest?.id
            )
        }
    }
}

extension CafeWrapped {
    /// The month with the most spent (ties: the earliest).
    var biggestMonth: Month? {
        months.max { $0.total < $1.total }
    }
}

#Preview {
    DaysPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x1D4ED8))
}
