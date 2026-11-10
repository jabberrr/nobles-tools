import Foundation

/// A semester's recap of a student's cafe purchases: totals, favorite items, when they buy, and a
/// "personality". Only cafes count (see `isCafe`), never the athletic store or bookstore.
///
/// Purchases are the positive charges. Refunds (negative charges) lower the money totals but
/// never count as purchases, units or items.
public struct CafeWrapped: Hashable, Sendable {
    public var period: Period
    /// Net spending at cafes in the period, tax included (refunds/negative charges subtract).
    public var total: Decimal
    /// Positive charges in the period.
    public var purchaseCount: Int
    /// Units bought: the sum of positive charges' quantities.
    public var itemCount: Int
    /// Distinct days with a purchase.
    public var dayCount: Int
    /// Distinct items (grouped by `String.matchKey` of the detail, whitespace collapsed).
    public var distinctItemCount: Int
    /// Every cafe with a purchase, most spent first (ties: name).
    public var cafes: [Cafe]
    /// Up to 5 items, most units first (ties: more spent, then name).
    public var topItems: [Item]
    /// 24 entries: purchases by hour of day, school time (`Calendar.school`).
    public var hourCounts: [Int]
    /// 7 entries: purchases by weekday, index 0 = Sunday … 6 = Saturday (Calendar weekday − 1).
    public var weekdayCounts: [Int]
    /// Each calendar month in the period that has a purchase, in order.
    public var months: [Month]
    /// The day with the most spent (ties: earliest).
    public var biggestDay: Day?
    /// The single priciest charge (ties: earliest).
    public var biggestPurchase: StoreCharge?
    /// The longest run of purchase days (see `Streak`); ties: earliest.
    public var longestStreak: Streak?
    /// The period's first cafe purchase.
    public var firstPurchase: StoreCharge?
    public var persona: CafePersona

    /// Recaps `semester` from `statement`, counting days from its start through `asOf` (or its
    /// end, whichever is first). `nil` when there's no positive cafe charge in that range.
    public init?(statement: StoreStatement, semester: Term, calendar: SchoolCalendar, asOf: LocalDate) {
        let span = semester.span
        let through = min(span.end, asOf)
        let charges = statement.charges
            .filter { Self.isCafe($0.storeName) }
            .map(DatedCharge.init)
            .filter { span.start <= $0.day && $0.day <= through }
            .sorted()
        let purchases = charges.filter(\.isPurchase)
        guard !purchases.isEmpty else { return nil }

        var hourCounts = Array(repeating: 0, count: 24)
        var weekdayCounts = Array(repeating: 0, count: 7)
        for purchase in purchases {
            hourCounts[purchase.hour] += 1
            weekdayCounts[purchase.day.weekday - 1] += 1
        }
        let items = Item.ranked(purchases)
        let days = Day.all(in: charges)

        period = Period(name: Self.periodName(for: span), span: span, through: through)
        total = charges.spent
        purchaseCount = purchases.count
        itemCount = purchases.units
        dayCount = days.count
        distinctItemCount = items.count
        cafes = Cafe.all(in: charges, overallTotal: total)
        topItems = Array(items.prefix(5))
        self.hourCounts = hourCounts
        self.weekdayCounts = weekdayCounts
        months = Month.all(in: charges)
        biggestDay = days.firstMax(by: \.total)
        biggestPurchase = purchases.firstMax(by: \.charge.total)?.charge
        longestStreak = Streak.runs(of: days.map(\.date), calendar: calendar).firstMax(by: \.length)
        firstPurchase = purchases.first?.charge
        persona = CafePersona(CafePersona.Evidence(
            favoriteUnits: items.first?.count ?? 0,
            units: itemCount,
            purchases: purchaseCount,
            eveningPurchases: hourCounts[17...].reduce(0, +),
            earlyPurchases: hourCounts[..<10].reduce(0, +),
            purchaseDays: dayCount,
            schoolDays: calendar.countedDays(in: DateSpan(start: span.start, end: through), counting: .schoolDays),
            distinctItems: distinctItemCount
        ))
    }

    /// `topItems.first`.
    public var favorite: Item? { topItems.first }

    /// The hour (0...23) with the most purchases, the earliest on ties; `nil` with none.
    public var peakHour: Int? {
        hourCounts.indices.filter { hourCounts[$0] > 0 }.firstMax { hourCounts[$0] }
    }

    /// The Calendar weekday (1 = Sunday … 7 = Saturday) with the most purchases; on ties, the
    /// first in Monday-first order (Monday … Saturday, then Sunday). `nil` with no purchases.
    public var favoriteWeekday: Int? {
        [2, 3, 4, 5, 6, 7, 1].filter { weekdayCounts[$0 - 1] > 0 }.firstMax { weekdayCounts[$0 - 1] }
    }

    /// The part of the day with the most purchases, the earliest on ties; `nil` with none.
    public var timeOfDay: CafeTimeOfDay? {
        func purchases(at time: CafeTimeOfDay) -> Int {
            time.hours.reduce(0) { $0 + hourCounts[$1] }
        }
        return CafeTimeOfDay.allCases.filter { purchases(at: $0) > 0 }.firstMax { purchases(at: $0) }
    }

    /// `total / dayCount`, rounded half-up to cents; 0 when `dayCount` is 0.
    public var averagePerDay: Decimal {
        guard dayCount > 0 else { return 0 }
        var exact = total / Decimal(dayCount)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 2, .plain)
        return rounded
    }
}

// MARK: - Semesters and stores

extension CafeWrapped {
    /// Whether a store is a cafe: its name contains "cafe"/"café", "snack", "coffee", "grill",
    /// "deli" or "kitchen" (accent/case-insensitive). "Athletic Store", "Bookstore" are not.
    public static func isCafe(_ storeName: String) -> Bool {
        storeName.containsAny(of: ["cafe", "snack", "coffee", "grill", "deli", "kitchen"])
    }

    /// The semester to recap on `date`: the one containing it, else the latest that has ended,
    /// else the first one; `nil` when the calendar has no semesters.
    public static func semester(in calendar: SchoolCalendar, on date: LocalDate) -> Term? {
        let semesters = calendar.terms
            .filter { $0.kind == .semester }
            .sorted { $0.span.start < $1.span.start }
        return semesters.first { $0.span.contains(date) }
            ?? semesters.last { $0.span.end < date }
            ?? semesters.first
    }

    /// Whether the recap should announce itself: from 6 days before the semester's last day
    /// through 21 days after it.
    public static func isReady(_ semester: Term, on date: LocalDate) -> Bool {
        let end = semester.span.end
        return DateSpan(start: end.adding(days: -6), end: end.adding(days: 21)).contains(date)
    }

    /// "Fall 2026" for a span starting July–December, "Spring 2027" for January–June (start's year).
    public static func periodName(for span: DateSpan) -> String {
        "\(span.start.month >= 7 ? "Fall" : "Spring") \(span.start.year)"
    }
}

// MARK: - Helpers

extension CafeWrapped {
    /// A cafe charge with its school-time day and hour worked out once. Orders chronologically.
    struct DatedCharge: Comparable {
        let charge: StoreCharge
        let day: LocalDate
        /// 0...23, school time.
        let hour: Int

        init(_ charge: StoreCharge) {
            self.charge = charge
            day = LocalDate(charge.madeAt)
            hour = Calendar.school.component(.hour, from: charge.madeAt)
        }

        /// A purchase rather than a refund or a zero line.
        var isPurchase: Bool { charge.total > 0 }

        /// Units bought; a purchase counts at least one, whatever its quantity says.
        var units: Int { isPurchase ? max(charge.quantity, 1) : 0 }

        static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.charge.madeAt, lhs.charge.id) < (rhs.charge.madeAt, rhs.charge.id)
        }
    }
}

extension Sequence<CafeWrapped.DatedCharge> {
    /// Net spending, tax included.
    var spent: Decimal { reduce(0) { $0 + $1.charge.total } }

    /// Units bought.
    var units: Int { reduce(0) { $0 + $1.units } }
}

extension Sequence {
    /// The element with the greatest `key`, the first one on ties; `nil` when empty.
    func firstMax<Key: Comparable>(by key: (Element) -> Key) -> Element? {
        var best: (element: Element, key: Key)?
        for element in self {
            let elementKey = key(element)
            if best.map({ elementKey > $0.key }) ?? true {
                best = (element, elementKey)
            }
        }
        return best?.element
    }
}
