import SwiftUI
import NoblesKit

/// The recap's cafes as the cafes page draws them: the three with the most spent each in a color
/// of their own, and any others together in a fourth, so the share bar, the figures and both charts
/// stack the same parts in the same order and colors.
struct CafeBreakdown {
    /// A cafe, or every cafe past the third together.
    struct Part: Identifiable {
        let id: String
        /// The cafe's name, or "2 more cafes".
        let name: String
        /// Net spending, tax included.
        let total: Decimal
        /// 0...1 of the recap's spending.
        let share: Double
        let color: Color
        /// 7 entries: spending by weekday, index 0 = Sunday, as `CafeWrapped.Cafe.weekdayTotals`.
        let weekdayTotals: [Decimal]
        /// Spending in each week, lined up with `CafeBreakdown.weekStarts`.
        let weeklyTotals: [Decimal]
    }

    /// Up to three cafes, most spent first.
    let cafes: [Part]
    /// The cafes after the third, together; `nil` with three or fewer.
    let rest: Part?
    /// The Monday starting each week of the recap.
    let weekStarts: [LocalDate]

    /// The most cafes drawn on their own.
    static let cafeLimit = 3

    /// The cafes' colors, biggest first: yellow, cyan and pink, apart in hue for color-blind
    /// readers too, and each at least 4.5:1 on the cafes page.
    private static var colors: [Color] {
        [WrappedStyle.highlight, Color(hex: 0xA5F3FC), Color(hex: 0xFBCFE8)]
    }

    /// The rest's color: dimmed white, at least 3:1 on the cafes page.
    private static var restColor: Color { Color.white.opacity(0.6) }

    init(_ wrapped: CafeWrapped) {
        weekStarts = wrapped.weekStarts
        cafes = zip(wrapped.cafes.prefix(Self.cafeLimit), Self.colors).map { cafe, color in
            Part(
                id: cafe.id,
                name: cafe.name,
                total: cafe.total,
                share: cafe.share,
                color: color,
                weekdayTotals: cafe.weekdayTotals,
                weeklyTotals: cafe.weeklyTotals
            )
        }
        let others = wrapped.cafes.dropFirst(Self.cafeLimit)
        rest = others.isEmpty ? nil : Part(
            id: "rest",
            name: WrappedFormat.count(others.count, "more cafe"),
            total: others.reduce(0) { $0 + $1.total },
            share: others.reduce(0) { $0 + $1.share },
            color: Self.restColor,
            weekdayTotals: Self.sum(others.map(\.weekdayTotals), count: 7),
            weeklyTotals: Self.sum(others.map(\.weeklyTotals), count: wrapped.weekStarts.count)
        )
    }

    /// The cafes, then the rest: the order everything stacks in.
    var parts: [Part] {
        cafes + (rest.map { [$0] } ?? [])
    }

    var colors: [Color] {
        parts.map(\.color)
    }

    // MARK: Charts

    /// Monday to Friday, plus Saturday or Sunday if anything was spent then, each with what was
    /// spent at each part and the day's whole-dollar total over it.
    var weekdayColumns: [WrappedStackedColumns.Column] {
        [2, 3, 4, 5, 6, 7, 1].compactMap { weekday in
            let spent = parts.map { $0.weekdayTotals[weekday - 1] }
            let total = Self.drawn(spent)
            let isWeekend = weekday == 1 || weekday == 7
            guard !isWeekend || total > 0 else { return nil }
            return WrappedStackedColumns.Column(
                id: weekday,
                values: spent.map(WrappedFormat.double),
                label: WrappedFormat.shortWeekday(weekday),
                figure: total > 0 ? total.usd(showsCents: false) : nil
            )
        }
    }

    /// Every week of the recap, empty ones included, with a month's name under the week it
    /// starts in.
    var weekColumns: [WrappedStackedColumns.Column] {
        let labels = monthLabels
        return weekStarts.indices.map { week in
            WrappedStackedColumns.Column(
                id: week,
                values: parts.map { WrappedFormat.double($0.weeklyTotals[week]) },
                label: labels[week]
            )
        }
    }

    /// The week with the most spent (ties: the earliest), as its column draws it: its Monday
    /// and that total. `nil` when nothing was spent in any week.
    var biggestWeek: (start: LocalDate, total: Decimal)? {
        let totals = weekStarts.indices.map { week in Self.drawn(parts.map { $0.weeklyTotals[week] }) }
        guard let peak = totals.max(), peak > 0, let week = totals.firstIndex(of: peak) else { return nil }
        return (weekStarts[week], peak)
    }

    /// Month names by week index: under each week whose Thursday (the day most of the week shares
    /// its month with) starts a new month, and under the first week when the next name is at
    /// least three weeks on, so names never crowd.
    private var monthLabels: [Int: String] {
        let months = weekStarts.map { $0.adding(days: 3).month }
        var labels: [Int: String] = [:]
        for week in months.indices.dropFirst() where months[week] != months[week - 1] {
            labels[week] = WrappedFormat.shortMonth(months[week])
        }
        if let first = months.first, (labels.keys.min() ?? .max) >= 3 {
            labels[0] = WrappedFormat.shortMonth(first)
        }
        return labels
    }

    /// What a stacked column draws: its positive parts, since a refund can't be stacked.
    private static func drawn(_ spent: [Decimal]) -> Decimal {
        spent.reduce(0) { $0 + max($1, 0) }
    }

    /// `lists` added up entry by entry, each `count` long.
    private static func sum(_ lists: [[Decimal]], count: Int) -> [Decimal] {
        (0..<count).map { index in lists.reduce(0) { $0 + $1[index] } }
    }
}
