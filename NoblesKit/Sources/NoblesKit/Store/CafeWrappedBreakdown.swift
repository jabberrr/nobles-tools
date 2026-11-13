import Foundation

extension CafeWrapped {
    /// Where the recap's spending went, as the cafes page stacks it: up to three cafes on their
    /// own, most spent first, then any others together, each split by weekday and week by week.
    public var cafeBreakdown: CafeBreakdown {
        CafeBreakdown(cafes: cafes, weekStarts: weekStarts)
    }

    /// The recap's cafes grouped for one set of stacked charts: `cafes` (up to `cafeLimit`) and
    /// `others`, in `groups` order wherever a column stacks them.
    public struct CafeBreakdown: Hashable, Sendable {
        /// A cafe, or the cafes past the third together.
        public struct Group: Hashable, Sendable, Identifiable {
            /// Its cafes' names, most spent first: one, unless it's the `others` of several.
            public var cafeNames: [String]
            /// Net spending, tax included.
            public var total: Decimal
            /// 0...1 of the recap's spending.
            public var share: Double

            public var id: String { cafeNames.joined(separator: "\n") }
        }

        /// One weekday's column.
        public struct WeekdayColumn: Hashable, Sendable {
            /// The Calendar weekday: 1 = Sunday … 7 = Saturday.
            public var weekday: Int
            /// Each group's net spending on it, in `groups` order; a refund can leave one below zero.
            public var spent: [Decimal]

            /// What the column stacks up to: its spending above zero, since a refund can't be stacked.
            public var total: Decimal { spent.stackedTotal }

            /// The index into `groups` of the group that spent the most (ties: the first); `nil`
            /// when none spent anything.
            public var leader: Int? {
                spent.indices.filter { spent[$0] > 0 }.firstMax { spent[$0] }
            }
        }

        /// One week's column.
        public struct WeekColumn: Hashable, Sendable {
            /// Its Monday.
            public var start: LocalDate
            /// Each group's net spending in it, in `groups` order; a refund can leave one below zero.
            public var spent: [Decimal]
            /// The month (1...12) named under this week: one starts here, judged by the week's
            /// Thursday (the day most of the week shares its month with). The first week names its
            /// month only when the next name is at least three weeks on, so names never crowd.
            public var month: Int?

            /// What the column stacks up to: its spending above zero, since a refund can't be stacked.
            public var total: Decimal { spent.stackedTotal }
        }

        /// The most cafes kept apart; any more are grouped as `others`.
        public static let cafeLimit = 3

        /// Up to `cafeLimit` cafes, most spent first.
        public var cafes: [Group]
        /// The cafes past the first `cafeLimit`, together; `nil` without any.
        public var others: Group?
        /// Monday to Friday, then Saturday and Sunday only if anything was spent on them.
        public var weekdays: [WeekdayColumn]
        /// Every week of the recap (`CafeWrapped.weekStarts`), empty ones included.
        public var weeks: [WeekColumn]

        /// `cafes`, then `others`: the order every column stacks in.
        public var groups: [Group] {
            cafes + (others.map { [$0] } ?? [])
        }

        /// The weekday with the most spent (ties: the first in `weekdays`); `nil` when nothing was.
        public var biggestWeekday: WeekdayColumn? {
            weekdays.filter { $0.total > 0 }.firstMax(by: \.total)
        }

        /// The week with the most spent (ties: the earliest); `nil` when nothing was.
        public var biggestWeek: WeekColumn? {
            weeks.filter { $0.total > 0 }.firstMax(by: \.total)
        }

        /// Groups `cafes` (most spent first) by `weekStarts`, which their `weeklyTotals` line up with.
        init(cafes: [Cafe], weekStarts: [LocalDate]) {
            let kept = cafes.prefix(Self.cafeLimit)
            let rest = cafes.dropFirst(Self.cafeLimit)
            let stacked = kept.map { [$0] } + (rest.isEmpty ? [] : [Array(rest)])
            self.cafes = kept.map { Group(of: [$0]) }
            others = rest.isEmpty ? nil : Group(of: Array(rest))
            weekdays = [2, 3, 4, 5, 6, 7, 1].compactMap { (weekday: Int) -> WeekdayColumn? in
                let spent = stacked.map { group in group.reduce(0) { $0 + $1.weekdayTotals[weekday - 1] } }
                let isWeekend = weekday == 1 || weekday == 7
                return isWeekend && spent.stackedTotal == 0 ? nil : WeekdayColumn(weekday: weekday, spent: spent)
            }
            let months = Self.monthLabels(for: weekStarts)
            weeks = weekStarts.indices.map { week in
                WeekColumn(
                    start: weekStarts[week],
                    spent: stacked.map { group in group.reduce(0) { $0 + $1.weeklyTotals[week] } },
                    month: months[week]
                )
            }
        }

        /// The month to name under each week, by index: see `WeekColumn.month`.
        private static func monthLabels(for weekStarts: [LocalDate]) -> [Int: Int] {
            let months = weekStarts.map { $0.adding(days: 3).month }
            var labels: [Int: Int] = [:]
            for week in months.indices.dropFirst() where months[week] != months[week - 1] {
                labels[week] = months[week]
            }
            if let first = months.first, (labels.keys.min() ?? .max) >= 3 {
                labels[0] = first
            }
            return labels
        }
    }
}

extension CafeWrapped.CafeBreakdown.Group {
    /// `cafes` together, named in their order.
    init(of cafes: [CafeWrapped.Cafe]) {
        cafeNames = cafes.map(\.name)
        total = cafes.reduce(0) { $0 + $1.total }
        share = cafes.reduce(0) { $0 + $1.share }
    }
}

private extension [Decimal] {
    /// The entries above zero, added up.
    var stackedTotal: Decimal {
        reduce(0) { $0 + Swift.max($1, 0) }
    }
}
