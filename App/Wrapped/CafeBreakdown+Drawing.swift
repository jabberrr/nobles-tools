import SwiftUI
import NoblesKit

/// How the cafes page draws a breakdown: each group's color, and the columns of its two charts.
extension CafeWrapped.CafeBreakdown {
    /// The cafes' colors, biggest first: yellow, cyan and pink, apart in hue for color-blind
    /// readers too, and each at least 4.5:1 on the cafes page.
    private static var cafeColors: [Color] {
        [WrappedStyle.highlight, Color(hex: 0xA5F3FC), Color(hex: 0xFBCFE8)]
    }

    /// The others' color: dimmed white, at least 3:1 on the cafes page.
    static var othersColor: Color { Color.white.opacity(0.6) }

    /// The color of `cafes[index]`.
    static func color(ofCafe index: Int) -> Color {
        cafeColors[index % cafeColors.count]
    }

    /// Each group's color, in `groups` order.
    var colors: [Color] {
        cafes.indices.map(Self.color(ofCafe:)) + (others == nil ? [] : [Self.othersColor])
    }

    /// The weekday chart: each day's spending by group, with its total over it in whole dollars,
    /// unless no day reached $20 and the cents matter.
    var weekdayChartColumns: [WrappedStackedColumns.Column] {
        let showsCents = weekdays.allSatisfy { $0.total < 20 }
        return weekdays.map { day in
            WrappedStackedColumns.Column(
                id: day.weekday,
                values: day.spent.map(WrappedFormat.double),
                label: WrappedFormat.shortWeekday(day.weekday),
                figure: day.total > 0 ? day.total.usd(showsCents: showsCents) : nil
            )
        }
    }

    /// The weekly strip: each week's spending by group, with a month's name under the week it
    /// starts in.
    var weekChartColumns: [WrappedStackedColumns.Column] {
        weeks.enumerated().map { index, week in
            WrappedStackedColumns.Column(
                id: index,
                values: week.spent.map(WrappedFormat.double),
                label: week.month.map(WrappedFormat.shortMonth)
            )
        }
    }
}

extension CafeWrapped.CafeBreakdown.Group {
    /// Its cafe's name, or "2 more cafes" for several together.
    var title: String {
        cafeNames.count == 1 ? cafeNames[0] : WrappedFormat.count(cafeNames.count, "more cafe")
    }
}
