import SwiftUI
import NoblesKit

/// What the semester came to: the total counting up, how often you went, and month by month.
struct TotalPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WrappedEyebrow(wrapped.period.isComplete ? "This semester" : "This semester so far", symbol: "dollarsign.circle.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("You spent")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isActive, delay: 0.25)
            CountingText(WrappedFormat.double(wrapped.total), isActive: isActive, duration: 1.6, delay: 0.7, format: WrappedFormat.dollars)
                .font(WrappedStyle.number(80))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(WrappedStyle.highlight)
                .wrappedReveal(isActive, delay: 0.55, style: .pop)
            facts
            Spacer(minLength: 16)
            if !wrapped.months.isEmpty {
                months
            }
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("on ", WrappedFormat.count(wrapped.purchaseCount, "cafe purchase"))
                .wrappedReveal(isActive, delay: 2.2)
            fact("across ", WrappedFormat.count(wrapped.dayCount, "day"))
                .wrappedReveal(isActive, delay: 2.5)
            if wrapped.dayCount > 1 {
                fact("That's ", wrapped.averagePerDay.usd(), " for every day you stopped by.")
                    .foregroundStyle(WrappedStyle.secondary)
                    .padding(.top, 6)
                    .wrappedReveal(isActive, delay: 2.9)
            }
        }
        .font(WrappedStyle.lead)
    }

    /// A line with its figure set large: "on **168 cafe purchases**".
    private func fact(_ lead: String, _ figure: String, _ trail: String = "") -> some View {
        let figureText = Text(figure).font(WrappedStyle.number(26)).foregroundStyle(Color.white)
        return Text("\(lead)\(figureText)\(trail)")
            .fixedSize(horizontal: false, vertical: true)
    }

    private var months: some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedEyebrow("Month by month", symbol: "chart.bar.fill")
                .wrappedReveal(isActive, delay: 3.1, style: .fade)
            WrappedBarChart(bars: monthBars, isActive: isActive, height: 110, delay: 3.2, stagger: 0.14)
        }
    }

    /// One bar per month, its total over it; the biggest month highlighted.
    private var monthBars: [WrappedBarChart.Bar] {
        let biggest = wrapped.months.max { $0.total < $1.total }
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

#Preview {
    TotalPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x065F46))
}
