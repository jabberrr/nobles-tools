import SwiftUI
import NoblesKit

/// What the semester came to: the total counting up, how often you went, and a line of your
/// spending adding up over the semester.
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
                .font(WrappedStyle.number(72))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(WrappedStyle.highlight)
                .wrappedReveal(isActive, delay: 0.55, style: .pop)
            facts
            Spacer(minLength: 16)
            growth
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 6) {
            fact("on ", WrappedFormat.count(wrapped.purchaseCount, "cafe purchase"))
                .wrappedReveal(isActive, delay: 2.0)
            fact("across ", WrappedFormat.count(wrapped.dayCount, "day"))
                .wrappedReveal(isActive, delay: 2.3)
            if wrapped.dayCount > 1 {
                fact("", wrapped.averagePerDay.usd(), " a day on average")
                    .foregroundStyle(WrappedStyle.secondary)
                    .padding(.top, 6)
                    .wrappedReveal(isActive, delay: 2.6)
            }
        }
        .font(WrappedStyle.lead)
    }

    /// A line with its figure set large: "on **168 cafe purchases**".
    private func fact(_ lead: String, _ figure: String, _ trail: String = "") -> some View {
        let figureText = Text(figure).font(WrappedStyle.number(24)).foregroundStyle(Color.white)
        return Text("\(lead)\(figureText)\(trail)")
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The running total across the semester so far.
    private var growth: some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedEyebrow("How it added up", symbol: "chart.line.uptrend.xyaxis")
                .wrappedReveal(isActive, delay: 2.8, style: .fade)
            WrappedLineChart(wrapped: wrapped, isActive: isActive, height: 130, delay: 2.9)
        }
    }
}

#Preview {
    TotalPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0x065F46))
}
