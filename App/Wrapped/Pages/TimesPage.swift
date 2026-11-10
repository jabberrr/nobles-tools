import SwiftUI
import NoblesKit

/// When you buy: your time-of-day title, purchases by hour with the busiest hour lit up, and how
/// they split across the day.
struct TimesPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    /// The hours the chart always covers, so a narrow day still reads as a day.
    private static let typicalHours = 7...21

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WrappedEyebrow("When you buy", symbol: "clock.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            if let timeOfDay = wrapped.timeOfDay {
                Image(systemName: timeOfDay.symbolName)
                    .font(WrappedStyle.symbol(44))
                    .foregroundStyle(WrappedStyle.highlight)
                    .wrappedReveal(isActive, delay: 0.3, style: .pop)
                Text(timeOfDay.title)
                    .font(WrappedStyle.title(32))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .wrappedReveal(isActive, delay: 0.5)
            }
            if let peak = wrapped.peakHour {
                peakLine(peak)
                    .wrappedReveal(isActive, delay: 0.9)
                Spacer(minLength: 12)
                WrappedBarChart(
                    bars: hourBars(peak: peak),
                    isActive: isActive,
                    height: 130,
                    spacing: 4,
                    maxBarWidth: 22,
                    delay: 1.2,
                    stagger: 0.05
                )
            }
            Spacer(minLength: 12)
            HStack(spacing: 8) {
                ForEach(Array(usedBuckets.enumerated()), id: \.element) { position, bucket in
                    BucketChip(bucket: bucket, share: wrapped.share(ofHours: bucket.hours), isTop: bucket == wrapped.timeOfDay)
                        .wrappedReveal(isActive, delay: 2.2 + 0.12 * Double(position), style: .pop)
                }
            }
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The parts of the day with a purchase, in order. A part with none is left out (the cafes
    /// aren't open at lunch), and the rest share the row.
    private var usedBuckets: [CafeTimeOfDay] {
        CafeTimeOfDay.allCases.filter { wrapped.share(ofHours: $0.hours) > 0 }
    }

    private func peakLine(_ peak: Int) -> some View {
        let count = WrappedFormat.count(wrapped.hourCounts[peak], "purchase")
        return Text("Your busiest hour was between \(WrappedFormat.hourSpan(peak)), with \(count).")
            .font(WrappedStyle.body)
            .foregroundStyle(WrappedStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// An hour per bar across the usual day, widened to any hour with a purchase; the peak lit up
    /// and named, and every third hour labelled.
    private func hourBars(peak: Int) -> [WrappedBarChart.Bar] {
        let used = wrapped.hourCounts.indices.filter { wrapped.hourCounts[$0] > 0 }
        let first = min(Self.typicalHours.lowerBound, used.first ?? peak)
        let last = max(Self.typicalHours.upperBound, used.last ?? peak)
        return (first...last).map { hour in
            WrappedBarChart.Bar(
                id: hour,
                value: Double(wrapped.hourCounts[hour]),
                label: hour % 3 == 0 ? WrappedFormat.compactHour(hour) : nil,
                valueLabel: hour == peak ? WrappedFormat.hour(hour) : nil,
                isHighlighted: hour == peak
            )
        }
    }
}

/// A part of the day and its share of your purchases; the biggest part filled in.
private struct BucketChip: View {
    let bucket: CafeTimeOfDay
    let share: Double
    let isTop: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: bucket.symbolName)
                .font(WrappedStyle.symbol(17))
            Text(WrappedFormat.percent(share))
                .font(WrappedStyle.number(18))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(bucket.displayName)
                .font(WrappedStyle.chartLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(isTop ? WrappedStyle.ink : Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(isTop ? WrappedStyle.highlight : WrappedStyle.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    TimesPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0xA62F17))
}
