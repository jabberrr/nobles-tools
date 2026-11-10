import Foundation

extension CafeWrapped {
    /// The stretch of a semester a recap covers.
    public struct Period: Hashable, Sendable {
        /// e.g. "Fall 2026".
        public var name: String
        /// The whole semester.
        public var span: DateSpan
        /// The last day counted: the semester's end, or the recap's as-of day if that's earlier.
        public var through: LocalDate

        /// Whether the recap covers the whole semester.
        public var isComplete: Bool { through >= span.end }
    }

    /// One thing bought, across every purchase of it.
    public struct Item: Hashable, Sendable, Identifiable {
        /// As last written (the most recent charge's detail, whitespace collapsed).
        public var name: String
        /// Units bought.
        public var count: Int
        /// Spent on it, tax included.
        public var total: Decimal
        /// `CafeItemArt.emoji(for: name)`.
        public var emoji: String
        /// Where most units were bought (ties: most recent).
        public var cafeName: String
        public var firstBought: Date
        public var lastBought: Date

        /// Its match key.
        public var id: String { name.matchKey }
    }

    /// One cafe's share of the recap.
    public struct Cafe: Hashable, Sendable, Identifiable {
        public var name: String
        /// Net spending here, tax included.
        public var total: Decimal
        public var purchaseCount: Int
        /// Distinct days with a purchase here.
        public var dayCount: Int
        /// `total` over the recap's overall total, 0...1 (0 when that's not positive).
        public var share: Double
        /// The most units bought here, with its count and total counting this cafe only.
        public var topItem: Item?

        public var id: String { name }
    }

    /// One calendar month's spending.
    public struct Month: Hashable, Sendable, Identifiable {
        public var year: Int
        /// 1...12.
        public var month: Int
        /// The short month name, e.g. "Sep".
        public var name: String
        /// Net spending, tax included.
        public var total: Decimal
        public var purchaseCount: Int

        /// e.g. "2026-09".
        public var id: String { String(format: "%04d-%02d", year, month) }
    }

    /// One day's spending.
    public struct Day: Hashable, Sendable {
        public var date: LocalDate
        /// Net spending, tax included.
        public var total: Decimal
        /// Units bought that day.
        public var itemCount: Int
    }

    /// Purchase days in a row, where only school days count as gaps: weekends, breaks and other
    /// non-school days between two purchase days don't break the run (`SchoolCalendar.isSchoolDay`).
    public struct Streak: Hashable, Sendable {
        public var start: LocalDate
        public var end: LocalDate
        /// Purchase days in the run, ≥ 1.
        public var length: Int
    }
}

// MARK: - Building

extension CafeWrapped.Item {
    /// Every item among `purchases`, grouped by the match key of the detail, most units first
    /// (ties: more spent, then name). Charges with no detail are left out.
    static func ranked(_ purchases: [CafeWrapped.DatedCharge]) -> [Self] {
        Dictionary(grouping: purchases) { $0.charge.detail.collapsingWhitespace.matchKey }
            .filter { !$0.key.isEmpty }
            .compactMap { Self(purchases: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.id < rhs.id
            }
    }

    /// The item bought in `purchases`, all of one item; `nil` when empty.
    private init?(purchases: [CafeWrapped.DatedCharge]) {
        guard let first = purchases.min(), let latest = purchases.max() else { return nil }
        // Units per cafe, with each cafe's latest purchase to break ties by recency.
        let cafes = Dictionary(grouping: purchases) { $0.charge.storeName.matchKey }
            .compactMap { _, charges in charges.max().map { (units: charges.units, latest: $0) } }
        let topCafe = cafes.max { ($0.units, $0.latest) < ($1.units, $1.latest) }?.latest ?? latest
        name = latest.charge.detail.collapsingWhitespace
        count = purchases.units
        total = purchases.spent
        emoji = CafeItemArt.emoji(for: name)
        cafeName = topCafe.charge.storeName
        firstBought = first.charge.madeAt
        lastBought = latest.charge.madeAt
    }
}

extension CafeWrapped.Cafe {
    /// Every cafe with a purchase among `charges`, most spent first (ties: name).
    static func all(in charges: [CafeWrapped.DatedCharge], overallTotal: Decimal) -> [Self] {
        Dictionary(grouping: charges) { $0.charge.storeName.matchKey }
            .compactMap { Self(charges: $0.value, overallTotal: overallTotal) }
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.name < $1.name }
    }

    /// The cafe of `charges` (all at one cafe, any order), named as most recently written; `nil`
    /// without a purchase.
    private init?(charges: [CafeWrapped.DatedCharge], overallTotal: Decimal) {
        let purchases = charges.filter(\.isPurchase)
        guard let latest = charges.max(), !purchases.isEmpty else { return nil }
        name = latest.charge.storeName
        total = charges.spent
        purchaseCount = purchases.count
        dayCount = Set(purchases.map(\.day)).count
        let fraction = overallTotal > 0 ? NSDecimalNumber(decimal: total / overallTotal).doubleValue : 0
        share = min(max(fraction, 0), 1)
        topItem = CafeWrapped.Item.ranked(purchases).first
    }
}

extension CafeWrapped.Month {
    /// Each calendar month among `charges` that has a purchase, in order.
    static func all(in charges: [CafeWrapped.DatedCharge]) -> [Self] {
        Dictionary(grouping: charges) { LocalDate(year: $0.day.year, month: $0.day.month, day: 1) }
            .sorted { $0.key < $1.key }
            .compactMap { Self(first: $0.key, charges: $0.value) }
    }

    /// The month starting on `first`, from its `charges`; `nil` without a purchase.
    private init?(first: LocalDate, charges: [CafeWrapped.DatedCharge]) {
        let purchaseCount = charges.filter(\.isPurchase).count
        guard purchaseCount > 0 else { return nil }
        year = first.year
        month = first.month
        name = Calendar.school.shortMonthSymbols[first.month - 1]
        total = charges.spent
        self.purchaseCount = purchaseCount
    }
}

extension CafeWrapped.Day {
    /// Each day among `charges` that has a purchase, in order.
    static func all(in charges: [CafeWrapped.DatedCharge]) -> [Self] {
        Dictionary(grouping: charges, by: \.day)
            .filter { $0.value.contains(where: \.isPurchase) }
            .map { Self(date: $0.key, total: $0.value.spent, itemCount: $0.value.units) }
            .sorted { $0.date < $1.date }
    }
}

extension CafeWrapped.Streak {
    /// The runs among purchase `days` (ascending and distinct), in order.
    static func runs(of days: [LocalDate], calendar: SchoolCalendar) -> [Self] {
        var runs: [Self] = []
        for day in days {
            if let run = runs.last, !calendar.hasSchoolDay(between: run.end, and: day) {
                runs[runs.count - 1].end = day
                runs[runs.count - 1].length += 1
            } else {
                runs.append(Self(start: day, end: day, length: 1))
            }
        }
        return runs
    }
}

private extension SchoolCalendar {
    /// Whether any school day falls strictly between `start` and `end`.
    func hasSchoolDay(between start: LocalDate, and end: LocalDate) -> Bool {
        countedDays(in: DateSpan(start: start.adding(days: 1), end: end.adding(days: -1)), counting: .schoolDays) > 0
    }
}
