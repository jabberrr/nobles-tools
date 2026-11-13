import SwiftUI
import NoblesKit

/// Where the money went: each cafe's share of spending in one bar, keyed by big figures in the
/// cafes' colors, then what was spent at each by weekday and week by week, stacked in the same
/// colors. With a single cafe, the page is about that cafe: its name, what was spent there, and
/// the same two charts.
struct CafesPage: View {
    private let wrapped: CafeWrapped
    private let isActive: Bool
    private let breakdown: CafeBreakdown

    private static let chartGap: CGFloat = 18
    /// The tallest each chart gets, its title included.
    private static let weekdayChartHeight: CGFloat = 220
    private static let weekChartHeight: CGFloat = 120

    init(wrapped: CafeWrapped, isActive: Bool) {
        self.wrapped = wrapped
        self.isActive = isActive
        breakdown = CafeBreakdown(wrapped)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cafe = onlyCafe {
                singleHeader(cafe)
            } else {
                header
            }
            charts
                .padding(.top, 22)
        }
        .padding(.horizontal, WrappedStyle.margin)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The cafe, when there's only one.
    private var onlyCafe: CafeBreakdown.Part? {
        breakdown.cafes.count == 1 ? breakdown.cafes.first : nil
    }

    /// The headline, the share bar, and a figure for each cafe.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            WrappedEyebrow("Your cafes", symbol: "cup.and.saucer.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text("Where you went")
                .font(WrappedStyle.title(34))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 10)
                .wrappedReveal(isActive, delay: 0.25)
            CafeShareBar(parts: breakdown.parts, isActive: isActive, delay: 0.5)
                .padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(breakdown.cafes.enumerated()), id: \.element.id) { position, cafe in
                    VStack(spacing: 0) {
                        if position > 0 {
                            WrappedRule()
                        }
                        CafeShareRow(cafe: cafe, isActive: isActive, delay: rowDelay(position) + 0.1)
                    }
                    .wrappedReveal(isActive, delay: rowDelay(position))
                }
                if let rest = breakdown.rest {
                    CafeRestRow(rest: rest)
                        .wrappedReveal(isActive, delay: rowDelay(breakdown.cafes.count))
                }
            }
            .padding(.top, 10)
        }
    }

    /// The one cafe's name as the headline, and what was spent there.
    private func singleHeader(_ cafe: CafeBreakdown.Part) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WrappedEyebrow("Your cafe", symbol: "cup.and.saucer.fill")
                .wrappedReveal(isActive, delay: 0.1, style: .fade)
            Text(cafe.name)
                .font(WrappedStyle.title(34))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .wrappedReveal(isActive, delay: 0.25)
            WrappedStat(label: "Spent", caption: WrappedFormat.count(wrapped.purchaseCount, "purchase"), size: 44) {
                CountingText(WrappedFormat.double(cafe.total), isActive: isActive, duration: 1.2, delay: 0.6, format: WrappedFormat.dollars)
            }
            .padding(.top, 18)
            .wrappedReveal(isActive, delay: 0.5)
        }
    }

    /// Both charts, sharing the height left under the header: the weekday chart about three
    /// fifths of it and the weekly strip the rest, each only as tall as still reads well.
    private var charts: some View {
        GeometryReader { proxy in
            let height = max(0, proxy.size.height - Self.chartGap)
            let weekdayHeight = min(Self.weekdayChartHeight, height * 0.62)
            VStack(alignment: .leading, spacing: Self.chartGap) {
                chartSection("By weekday", delay: chartsDelay) {
                    WrappedStackedColumns(
                        columns: breakdown.weekdayColumns,
                        colors: breakdown.colors,
                        isActive: isActive,
                        spacing: 14,
                        maxColumnWidth: 64,
                        delay: chartsDelay + 0.1
                    )
                }
                .frame(height: weekdayHeight)
                chartSection("Week by week", delay: chartsDelay + 0.7) {
                    WrappedStackedColumns(
                        columns: breakdown.weekColumns,
                        colors: breakdown.colors,
                        isActive: isActive,
                        spacing: 4,
                        maxColumnWidth: 28,
                        labelAlignment: .leading,
                        delay: chartsDelay + 0.8,
                        stagger: 0.03
                    )
                }
                .frame(height: min(Self.weekChartHeight, height - weekdayHeight))
            }
        }
        .frame(minHeight: 190)
    }

    /// A chart under its small uppercase title.
    private func chartSection<Chart: View>(_ title: String, delay: Double, @ViewBuilder chart: () -> Chart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WrappedCardLabel(title)
                .wrappedReveal(isActive, delay: delay, style: .fade)
            chart()
        }
    }

    private func rowDelay(_ position: Int) -> Double {
        0.75 + 0.2 * Double(position)
    }

    /// The charts start once the cafes' figures are in.
    private var chartsDelay: Double {
        onlyCafe == nil ? rowDelay(breakdown.parts.count) + 0.2 : 0.9
    }
}

/// A cafe's share as a big figure in its color, which keys the cafe in the bar and the charts,
/// beside its name and what was spent there.
private struct CafeShareRow: View {
    let cafe: CafeBreakdown.Part
    let isActive: Bool
    let delay: Double

    var body: some View {
        HStack(spacing: 12) {
            CountingText(cafe.share, isActive: isActive, duration: 1, delay: delay, format: WrappedFormat.percent)
                .font(WrappedStyle.number(34))
                .monospacedDigit()
                .foregroundStyle(cafe.color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: CafeShareRow.figureWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(cafe.name)
                    .font(WrappedStyle.itemName)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(cafe.total.usd())
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    /// The width the share figures take, so the names line up.
    static let figureWidth: CGFloat = 96
}

/// The cafes past the third, together: a swatch of their color in the figures' column, how many
/// there are, and what was spent at them.
private struct CafeRestRow: View {
    let rest: CafeBreakdown.Part

    var body: some View {
        VStack(spacing: 0) {
            WrappedRule()
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(rest.color)
                    .frame(width: 18, height: 10)
                    .frame(width: CafeShareRow.figureWidth, alignment: .leading)
                Text(rest.name)
                Spacer(minLength: 8)
                Text(rest.total.usd())
                    .foregroundStyle(WrappedStyle.secondary)
            }
            .font(WrappedStyle.strongCaption)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    CafesPage(wrapped: .sample, isActive: true)
        .foregroundStyle(.white)
        .background(Color(hex: 0xB42318))
}
