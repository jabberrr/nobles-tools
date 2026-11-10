import SwiftUI
import NoblesKit

/// Your week: purchases by weekday with your day lit up, then your biggest day.
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
                Text("\(WrappedFormat.weekday(favorite))s were your day")
                    .font(WrappedStyle.title(32))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive, delay: 0.3)
            }
            Text("You stopped by on \(WrappedFormat.count(wrapped.dayCount, "different day")).")
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isActive, delay: 0.6)
            Spacer(minLength: 12)
            WrappedBarChart(bars: weekdayBars, isActive: isActive, height: 150, delay: 0.9, stagger: 0.1)
            Spacer(minLength: 12)
            if let day = wrapped.biggestDay {
                BiggestDayCard(day: day, isActive: isActive, delay: 1.9)
            }
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}

/// The day you spent the most: the date, then the amount counting up.
private struct BiggestDayCard: View {
    let day: CafeWrapped.Day
    let isActive: Bool
    let delay: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WrappedEyebrow("Your biggest day", symbol: "flame.fill")
            Text(WrappedFormat.day(day.date))
                .font(WrappedStyle.title(24))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                CountingText(WrappedFormat.double(day.total), isActive: isActive, duration: 1, delay: delay + 0.3, format: WrappedFormat.dollars)
                    .font(WrappedStyle.number(40))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(WrappedStyle.highlight)
                    .layoutPriority(1)
                Text("on \(WrappedFormat.count(day.itemCount, "item"))")
                    .font(WrappedStyle.lead)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .wrappedCard(padding: 18)
        .wrappedReveal(isActive, delay: delay, style: .slide(.bottom))
    }
}

#Preview {
    DaysPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x1D4ED8))
}
