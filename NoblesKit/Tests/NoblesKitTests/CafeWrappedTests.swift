import Foundation
import Testing
@testable import NoblesKit

struct CafeWrappedTests {
    private let calendar = SchoolCalendar.nobles2026_27

    private func fall() throws -> Term {
        try #require(CafeWrapped.semester(in: calendar, on: LocalDate(2026, 9, 8)))
    }

    private static let gleason = "Cafe at Gleason Hall"
    private static let cafe2000 = "Cafe 2000"

    private static func money(_ amount: String) -> Decimal {
        Decimal(string: amount) ?? .nan
    }

    private static func charge(
        _ id: Int, _ store: String, _ detail: String, _ amount: String, tax: String = "0", quantity: Int = 1,
        on day: LocalDate, at hour: Int, _ minute: Int = 0
    ) -> StoreCharge {
        StoreCharge(
            id: id, storeName: store, detail: detail, quantity: quantity,
            amount: money(amount), tax: money(tax), madeAt: day.at(hour: hour, minute: minute), postedOn: day
        )
    }

    private static func streak(_ start: LocalDate, _ end: LocalDate, _ length: Int) -> CafeWrapped.Streak {
        CafeWrapped.Streak(start: start, end: end, length: length)
    }

    private static func statement(_ charges: [StoreCharge]) -> StoreStatement {
        StoreStatement(charges: charges, totalsByStore: [], grandTotal: 0, fetchedAt: LocalDate(2026, 12, 18).at(hour: 23))
    }

    /// The recap of purchases of `(detail, day, hour)` at Gleason, each costing $2.00.
    private func recap(
        _ purchases: [(String, LocalDate, Int)], asOf: LocalDate = LocalDate(2026, 12, 18)
    ) throws -> CafeWrapped? {
        let charges = purchases.enumerated().map { index, purchase in
            Self.charge(index + 1, Self.gleason, purchase.0, "2.00", on: purchase.1, at: purchase.2)
        }
        return CafeWrapped(statement: Self.statement(charges), semester: try fall(), calendar: calendar, asOf: asOf)
    }

    // MARK: Hand-built recap

    /// Two cafes, an athletic-store and a bookstore charge, tax, a refund, a whitespace variant, and
    /// charges before the semester and after the as-of day.
    private static let mixedCharges: [StoreCharge] = [
        charge(1, gleason, "Iced Latte", "4.00", on: LocalDate(2026, 9, 4), at: 10), // before the semester
        charge(2, gleason, "Iced Latte", "4.00", on: LocalDate(2026, 9, 8), at: 7, 55),
        charge(3, gleason, "Everything Bagel", "3.00", on: LocalDate(2026, 9, 8), at: 10, 20),
        charge(4, gleason, "Iced Latte", "4.00", on: LocalDate(2026, 9, 9), at: 10, 15),
        charge(5, cafe2000, "Chocolate Chip Cookie", "4.50", quantity: 2, on: LocalDate(2026, 9, 9), at: 19, 30),
        charge(6, "Athletic Store", "Nobles Hoodie", "45.00", tax: "2.81", on: LocalDate(2026, 9, 10), at: 12, 30),
        charge(7, gleason, "Turkey Panini", "7.50", tax: "0.47", on: LocalDate(2026, 9, 11), at: 12, 40),
        charge(8, gleason, "Iced  latte ", "4.00", on: LocalDate(2026, 9, 14), at: 10, 30),
        charge(9, gleason, "Turkey Panini", "-7.50", tax: "-0.47", on: LocalDate(2026, 9, 15), at: 12, 10), // refund
        charge(10, cafe2000, "Banana", "1.50", on: LocalDate(2026, 9, 15), at: 20, 5),
        charge(11, "Bookstore", "Notebook", "5.00", on: LocalDate(2026, 9, 22), at: 11),
        charge(12, gleason, "Everything Bagel", "3.00", on: LocalDate(2026, 10, 9), at: 10, 45),
        charge(13, gleason, "Apple", "1.50", on: LocalDate(2026, 10, 13), at: 12, 15),
        charge(14, gleason, "Iced Latte", "4.00", on: LocalDate(2026, 11, 2), at: 10), // after the as-of day
    ]

    private func mixed(asOf: LocalDate = LocalDate(2026, 10, 31)) throws -> CafeWrapped {
        let statement = Self.statement(Self.mixedCharges)
        return try #require(CafeWrapped(statement: statement, semester: try fall(), calendar: calendar, asOf: asOf))
    }

    @Test func totalsCountOnlyCafesInThePeriod() throws {
        let wrapped = try mixed()

        #expect(wrapped.period.name == "Fall 2026")
        #expect(wrapped.period.span == DateSpan(start: LocalDate(2026, 9, 8), end: LocalDate(2026, 12, 18)))
        #expect(wrapped.period.through == LocalDate(2026, 10, 31))
        #expect(!wrapped.period.isComplete)

        // Tax included, the refund subtracted; the athletic store, the bookstore and the charges
        // outside Sep 8 – Oct 31 left out.
        #expect(wrapped.total == Self.money("25.50"))
        #expect(wrapped.purchaseCount == 9)
        #expect(wrapped.itemCount == 10) // the cookies were a pair
        #expect(wrapped.dayCount == 7)
        #expect(wrapped.distinctItemCount == 6)
        #expect(wrapped.averagePerDay == Self.money("3.64")) // 25.50 / 7 = 3.642…
        #expect(wrapped.firstPurchase?.id == 2)
        #expect(wrapped.biggestPurchase?.id == 7) // $7.97 with tax
    }

    @Test func ranksItemsByUnitsThenSpendThenName() throws {
        let wrapped = try mixed()

        #expect(wrapped.topItems.map(\.name) == [
            "Iced latte", "Everything Bagel", "Chocolate Chip Cookie", "Turkey Panini", "Apple",
        ])
        #expect(wrapped.topItems.map(\.count) == [3, 2, 2, 1, 1])
        #expect(wrapped.topItems.map(\.total) == ["12.00", "6.00", "4.50", "7.97", "1.50"].map(Self.money))
        #expect(wrapped.topItems.map(\.emoji) == ["🧋", "🥯", "🍪", "🥪", "🍎"])

        // "Iced Latte" and "Iced  latte " are one item, named as last written.
        let favorite = try #require(wrapped.favorite)
        #expect(favorite.id == "iced latte")
        #expect(favorite.cafeName == Self.gleason)
        #expect(favorite.firstBought == LocalDate(2026, 9, 8).at(hour: 7, minute: 55))
        #expect(favorite.lastBought == LocalDate(2026, 9, 14).at(hour: 10, minute: 30))

        // The cookies cost $4.50 against the bagels' $6.00; Apple beats Banana by name.
        #expect(wrapped.topItems.first { $0.name == "Turkey Panini" }?.total == Self.money("7.97")) // refund not netted
        #expect(!wrapped.topItems.contains { $0.name == "Banana" })
    }

    @Test func splitsByCafe() throws {
        let cafes = try mixed().cafes

        #expect(cafes.map(\.name) == [Self.gleason, Self.cafe2000])
        #expect(cafes.map(\.total) == [Self.money("19.50"), Self.money("6.00")])
        #expect(cafes.map(\.purchaseCount) == [7, 2])
        #expect(cafes.map(\.dayCount) == [6, 2])
        #expect(abs(cafes[0].share - 19.5 / 25.5) < 1e-9)
        #expect(abs(cafes[1].share - 6 / 25.5) < 1e-9)
        #expect(cafes.map(\.id) == cafes.map(\.name))
    }

    @Test func splitsEachCafeByWeekdayAndWeek() throws {
        let wrapped = try mixed()

        // From the week of Tue Sep 8 through the week of Sat Oct 31, Mondays to Sundays.
        #expect(wrapped.weekStarts == [
            LocalDate(2026, 9, 7), LocalDate(2026, 9, 14), LocalDate(2026, 9, 21), LocalDate(2026, 9, 28),
            LocalDate(2026, 10, 5), LocalDate(2026, 10, 12), LocalDate(2026, 10, 19), LocalDate(2026, 10, 26),
        ])

        // Net of the panini refund on Tue Sep 15, which outweighs Gleason's Monday that week.
        let gleason = wrapped.cafes[0]
        #expect(gleason.weekdayTotals == ["0", "4.00", "0.53", "4.00", "0", "10.97", "0"].map(Self.money))
        #expect(gleason.weeklyTotals == ["18.97", "-3.97", "0", "0", "3.00", "1.50", "0", "0"].map(Self.money))

        // Cafe 2000's evening charges stay on their school-time day.
        let cafe2000 = wrapped.cafes[1]
        #expect(cafe2000.weekdayTotals == ["0", "0", "1.50", "4.50", "0", "0", "0"].map(Self.money))
        #expect(cafe2000.weeklyTotals == ["4.50", "1.50", "0", "0", "0", "0", "0", "0"].map(Self.money))

        for cafe in wrapped.cafes {
            #expect(cafe.weekdayTotals.reduce(0, +) == cafe.total)
            #expect(cafe.weeklyTotals.reduce(0, +) == cafe.total)
        }
    }

    @Test func weeksRunMondayToSunday() {
        func weeks(_ start: LocalDate, _ end: LocalDate) -> [LocalDate] {
            CafeWrapped.weekStarts(from: start, through: end)
        }

        // Spring starts on a Monday.
        #expect(weeks(LocalDate(2027, 1, 4), LocalDate(2027, 1, 4)) == [LocalDate(2027, 1, 4)])
        // A Sunday ends its week; the Monday after starts the next.
        #expect(weeks(LocalDate(2026, 9, 8), LocalDate(2026, 9, 13)) == [LocalDate(2026, 9, 7)])
        #expect(weeks(LocalDate(2026, 9, 8), LocalDate(2026, 9, 14)) == [LocalDate(2026, 9, 7), LocalDate(2026, 9, 14)])
        #expect(weeks(LocalDate(2026, 9, 13), LocalDate(2026, 9, 14)) == [LocalDate(2026, 9, 7), LocalDate(2026, 9, 14)])
        // Across the end of daylight saving time (Sun Nov 1).
        #expect(weeks(LocalDate(2026, 10, 30), LocalDate(2026, 11, 3)) == [LocalDate(2026, 10, 26), LocalDate(2026, 11, 2)])
    }

    @Test func weekendChargesCountInTheirWeek() throws {
        let charges = [
            Self.charge(1, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 9, 12), at: 10), // Saturday
            Self.charge(2, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 9, 13), at: 10), // Sunday
            Self.charge(3, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 9, 14), at: 10), // Monday
        ]
        let asOf = LocalDate(2026, 9, 14)
        let wrapped = try #require(CafeWrapped(statement: Self.statement(charges), semester: try fall(), calendar: calendar, asOf: asOf))
        let cafe = try #require(wrapped.cafes.first)

        #expect(wrapped.weekStarts == [LocalDate(2026, 9, 7), LocalDate(2026, 9, 14)])
        #expect(cafe.weeklyTotals == ["8.00", "4.00"].map(Self.money))
        #expect(cafe.weekdayTotals == ["4.00", "4.00", "0", "0", "0", "0", "4.00"].map(Self.money))
    }

    @Test func bucketsTimesInSchoolTime() throws {
        let wrapped = try mixed()

        var hours = Array(repeating: 0, count: 24)
        hours[7] = 1
        hours[10] = 4
        hours[12] = 2 // the refund at 12:10 isn't a purchase
        hours[19] = 1
        hours[20] = 1
        #expect(wrapped.hourCounts == hours)
        #expect(wrapped.weekdayCounts == [0, 1, 4, 2, 0, 2, 0])
        #expect(wrapped.peakHour == 10)
        #expect(wrapped.favoriteWeekday == 3) // Tuesday
        #expect(wrapped.timeOfDay == .morning)

        #expect(wrapped.share(ofHours: 17...23) == 2.0 / 9)
        #expect(wrapped.share(ofHours: 0...9) == 1.0 / 9)
        #expect(wrapped.share(ofHours: 10...10) == 4.0 / 9)
        #expect(wrapped.share(ofHours: 0...23) == 1)
        #expect(wrapped.share(ofHours: 20...30) == 1.0 / 9) // hours past 23 count nothing
    }

    @Test func timeOfDayHoldsThePeakHour() throws {
        let day = LocalDate(2026, 9, 8)
        // More purchases in the morning overall, but the busiest hour is 12:00.
        let lunch = try #require(try recap([("A", day, 7), ("B", day, 8), ("C", day, 9), ("D", day, 12), ("E", day, 12)]))
        #expect(lunch.peakHour == 12)
        #expect(lunch.timeOfDay == .midday)

        var none = lunch
        none.purchaseCount = 0
        none.hourCounts = Array(repeating: 0, count: 24)
        #expect(none.peakHour == nil)
        #expect(none.timeOfDay == nil)
        #expect(none.share(ofHours: 0...23) == 0)
    }

    @Test func groupsMonthsAndDays() throws {
        let wrapped = try mixed()

        // Each purchase day, net of refunds: Sep 15's banana less the panini refund.
        #expect(wrapped.days.map(\.date) == [
            LocalDate(2026, 9, 8), LocalDate(2026, 9, 9), LocalDate(2026, 9, 11), LocalDate(2026, 9, 14),
            LocalDate(2026, 9, 15), LocalDate(2026, 10, 9), LocalDate(2026, 10, 13),
        ])
        #expect(wrapped.days.map(\.total) == ["7.00", "8.50", "7.97", "4.00", "-6.47", "3.00", "1.50"].map(Self.money))
        #expect(wrapped.days.map(\.itemCount) == [2, 3, 1, 1, 1, 1, 1])
        #expect(wrapped.days.count == wrapped.dayCount)
        #expect(wrapped.days.reduce(0) { $0 + $1.total } == wrapped.total)

        #expect(wrapped.months.map(\.id) == ["2026-09", "2026-10"])
        #expect(wrapped.months.map(\.name) == ["Sep", "Oct"])
        #expect(wrapped.months.map(\.total) == [Self.money("21.00"), Self.money("4.50")])
        #expect(wrapped.months.map(\.purchaseCount) == [7, 2])

        let biggest = try #require(wrapped.biggestDay)
        #expect(biggest.date == LocalDate(2026, 9, 9))
        #expect(biggest.total == Self.money("8.50"))
        #expect(biggest.itemCount == 3)
    }

    @Test func streaksSpanWeekendsButNotMissedSchoolDays() throws {
        // Sep 8–9, a missed Thursday, then Fri Sep 11 → Mon Sep 14 → Tue Sep 15 over the weekend.
        let streak = try #require(try mixed().longestStreak)
        #expect(streak == Self.streak(LocalDate(2026, 9, 11), LocalDate(2026, 9, 15), 3))

        // Thu Oct 8, Fri Oct 9, then Tue Oct 13 across the weekend and Indigenous Peoples' Day.
        let overBreak = try #require(try recap([
            ("Latte", LocalDate(2026, 10, 8), 10), ("Latte", LocalDate(2026, 10, 9), 10),
            ("Latte", LocalDate(2026, 10, 13), 10), ("Latte", LocalDate(2026, 10, 15), 10),
        ]))
        #expect(overBreak.longestStreak == Self.streak(LocalDate(2026, 10, 8), LocalDate(2026, 10, 13), 3))

        // A weekend purchase is a purchase day too.
        let weekend = try #require(try recap([
            ("Latte", LocalDate(2026, 9, 11), 10), ("Latte", LocalDate(2026, 9, 12), 10), ("Latte", LocalDate(2026, 9, 14), 10),
        ]))
        #expect(weekend.longestStreak?.length == 3)
    }

    @Test func coversTheWholeSemesterOnceItEnds() throws {
        let wrapped = try mixed(asOf: LocalDate(2027, 1, 5))

        #expect(wrapped.period.through == LocalDate(2026, 12, 18))
        #expect(wrapped.period.isComplete)
        #expect(wrapped.purchaseCount == 10) // now with Nov 2
        #expect(wrapped.total == Self.money("29.50"))
        #expect(wrapped.favorite?.count == 4)
    }

    @Test func breaksTiesTowardTheEarliest() throws {
        let wrapped = try #require(try recap([
            ("Muffin", LocalDate(2026, 9, 13), 14), // Sunday
            ("Scone", LocalDate(2026, 9, 14), 8), // Monday
            ("Bagel", LocalDate(2026, 9, 17), 8),
            ("Toast", LocalDate(2026, 9, 18), 14),
        ]))

        #expect(wrapped.peakHour == 8)
        #expect(wrapped.favoriteWeekday == 2) // Monday before Sunday, both with one
        #expect(wrapped.timeOfDay == .morning) // 8:00 and 14:00 tie; the peak is the earlier
        #expect(wrapped.biggestDay?.date == LocalDate(2026, 9, 13))
        #expect(wrapped.biggestPurchase?.detail == "Muffin")
        #expect(wrapped.longestStreak == Self.streak(LocalDate(2026, 9, 13), LocalDate(2026, 9, 14), 2)) // vs Sep 17–18

        let weekend = try #require(try recap([("Muffin", LocalDate(2026, 9, 12), 9), ("Scone", LocalDate(2026, 9, 13), 9)]))
        #expect(weekend.favoriteWeekday == 7) // Saturday before Sunday
    }

    @Test func namesTheCafeWithTheMostUnits() throws {
        let day = LocalDate(2026, 9, 8)
        func cafe(_ charges: [StoreCharge]) throws -> String? {
            let wrapped = CafeWrapped(statement: Self.statement(charges), semester: try fall(), calendar: calendar, asOf: day)
            return wrapped?.favorite?.cafeName
        }

        // One each: the most recent wins.
        #expect(try cafe([
            Self.charge(1, Self.gleason, "Cookie", "2.00", on: day, at: 10),
            Self.charge(2, Self.cafe2000, "Cookie", "2.00", on: day, at: 19),
        ]) == Self.cafe2000)
        // More units at Gleason, even though Cafe 2000 was more recent.
        #expect(try cafe([
            Self.charge(1, Self.gleason, "Cookie", "4.00", quantity: 2, on: day, at: 10),
            Self.charge(2, Self.cafe2000, "Cookie", "2.00", on: day, at: 19),
        ]) == Self.gleason)
    }

    @Test func isNilWithoutACafePurchase() throws {
        let fall = try fall()
        func recapCharges(_ charges: [StoreCharge], asOf: LocalDate = LocalDate(2026, 12, 18)) -> CafeWrapped? {
            CafeWrapped(statement: Self.statement(charges), semester: fall, calendar: calendar, asOf: asOf)
        }
        let latte = Self.charge(1, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 9, 8), at: 10)

        #expect(recapCharges([]) == nil)
        #expect(recapCharges([Self.charge(1, "Athletic Store", "Cap", "30.00", on: LocalDate(2026, 9, 8), at: 15)]) == nil)
        #expect(recapCharges([Self.charge(1, Self.gleason, "Latte", "-4.00", on: LocalDate(2026, 9, 8), at: 10)]) == nil)
        #expect(recapCharges([Self.charge(1, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 12, 21), at: 10)]) == nil)
        #expect(recapCharges([latte], asOf: LocalDate(2026, 9, 7)) == nil) // before the semester starts
        #expect(recapCharges([latte], asOf: LocalDate(2026, 9, 8)) != nil)
    }

    @Test func keepsRefundOnlyDaysInTheDailySeries() throws {
        let charges = [
            Self.charge(1, Self.gleason, "Latte", "4.00", on: LocalDate(2026, 9, 8), at: 14),
            Self.charge(2, Self.gleason, "Bagel", "3.00", on: LocalDate(2026, 9, 9), at: 14),
            Self.charge(3, Self.gleason, "Latte", "-4.00", on: LocalDate(2026, 9, 10), at: 14),
        ]
        let wrapped = try #require(CafeWrapped(statement: Self.statement(charges), semester: try fall(), calendar: calendar, asOf: LocalDate(2026, 12, 18)))

        #expect(wrapped.days.map(\.date) == [LocalDate(2026, 9, 8), LocalDate(2026, 9, 9), LocalDate(2026, 9, 10)])
        #expect(wrapped.days.map(\.itemCount) == [1, 1, 0])
        #expect(wrapped.days.reduce(0) { $0 + $1.total } == wrapped.total)
        // A refund isn't a visit, so it counts toward neither the days nor the streak.
        #expect(wrapped.dayCount == 2)
        #expect(wrapped.longestStreak?.length == 2)
        #expect(wrapped.biggestDay?.date == LocalDate(2026, 9, 8))
    }

    // MARK: Personas

    @Test func personaRulesApplyInOrder() {
        func persona(
            favorite: Int = 1, units: Int = 20, purchases: Int = 20, evening: Int = 0, early: Int = 0,
            days: Int = 1, schoolDays: Int = 70, distinct: Int = 1
        ) -> CafePersona {
            CafePersona(CafePersona.Evidence(
                favoriteUnits: favorite, units: units, purchases: purchases, eveningPurchases: evening,
                earlyPurchases: early, purchaseDays: days, schoolDays: schoolDays, distinctItems: distinct
            ))
        }

        #expect(persona(favorite: 5, units: 20) == .loyalist)
        #expect(persona(favorite: 5, units: 21) == .dropIn) // under a quarter
        #expect(persona(favorite: 4, units: 4) == .dropIn) // too few
        #expect(persona(favorite: 5, units: 20, evening: 20) == .loyalist) // first rule wins

        #expect(persona(purchases: 5, evening: 2) == .nightOwl)
        #expect(persona(purchases: 6, evening: 2) == .dropIn)
        #expect(persona(purchases: 6, evening: 3, early: 3) == .nightOwl)

        #expect(persona(purchases: 6, early: 3) == .earlyBird)
        #expect(persona(purchases: 7, early: 3) == .dropIn)

        #expect(persona(days: 35, schoolDays: 70) == .regular)
        #expect(persona(days: 34, schoolDays: 70) == .dropIn)
        #expect(persona(days: 1, schoolDays: 0) == .dropIn)

        #expect(persona(purchases: 30, distinct: 12) == .explorer)
        #expect(persona(purchases: 31, distinct: 12) == .dropIn)
        #expect(persona(purchases: 11, distinct: 11) == .dropIn)
    }

    @Test func personaReadsTimesAndDaysFromCharges() throws {
        let day = LocalDate(2026, 9, 8)
        let night = try #require(try recap([("A", day, 17), ("B", day, 21), ("C", day, 12), ("D", day, 12), ("E", day, 12)]))
        #expect(night.persona == .nightOwl) // 17:00 counts as evening

        let early = try #require(try recap([("A", day, 7), ("B", day, 9), ("C", day, 10), ("D", day, 12)]))
        #expect(early.persona == .earlyBird)
        let tenOClock = try #require(try recap([("A", day, 7), ("B", day, 10), ("C", day, 10), ("D", day, 12)]))
        #expect(tenOClock.persona == .dropIn) // 10:00 isn't early

        // Two of the first four school days (Sep 8–11).
        let regular = try #require(try recap([("A", day, 12), ("B", day.adding(days: 1), 12)], asOf: LocalDate(2026, 9, 11)))
        #expect(regular.persona == .regular)
        let dropIn = try #require(try recap([("A", day, 12), ("B", day, 12)], asOf: LocalDate(2026, 9, 11)))
        #expect(dropIn.persona == .dropIn)
    }

    @Test func personaCopyIsComplete() {
        for persona in CafePersona.allCases {
            #expect(!persona.title.isEmpty && !persona.tagline.isEmpty && !persona.emoji.isEmpty)
        }
        #expect(CafePersona.loyalist.title == "The Superfan")
        #expect(CafePersona.regular.tagline == "At the cafe most days")
        #expect(CafeTimeOfDay.allCases.flatMap { Array($0.hours) } == Array(0...23))
        #expect(CafeTimeOfDay.allCases.map(\.displayName) == ["Morning", "Lunch", "Afternoon", "Evening"])
        #expect(CafeTimeOfDay.morning.title == "Morning person")

        // Plain words: no dashes or semicolons in a sentence.
        let copy = CafePersona.allCases.flatMap { [$0.title, $0.tagline] } + CafeTimeOfDay.allCases.map(\.title)
        for text in copy {
            #expect(!text.contains { "—–;".contains($0) }, "\(text)")
        }
    }

    // MARK: Semesters and stores

    @Test func picksTheSemesterToRecap() throws {
        func semester(_ date: LocalDate) -> String? {
            CafeWrapped.semester(in: calendar, on: date)?.name
        }

        #expect(semester(LocalDate(2026, 8, 1)) == "Fall Semester") // before any: the first
        #expect(semester(LocalDate(2026, 10, 1)) == "Fall Semester")
        #expect(semester(LocalDate(2026, 12, 14)) == "Fall Semester") // its last week
        #expect(semester(LocalDate(2026, 12, 25)) == "Fall Semester") // winter break: the one just ended
        // Spring starts Jan 4, but Fall's recap stays ready through Jan 8.
        #expect(semester(LocalDate(2027, 1, 4)) == "Fall Semester")
        #expect(semester(LocalDate(2027, 1, 8)) == "Fall Semester")
        #expect(semester(LocalDate(2027, 1, 9)) == "Spring Semester")
        #expect(semester(LocalDate(2027, 6, 25)) == "Spring Semester")
        #expect(semester(LocalDate(2027, 7, 1)) == "Spring Semester") // after the year: the last
        let empty = SchoolCalendar(name: "Empty", terms: [], breaks: [])
        #expect(CafeWrapped.semester(in: empty, on: LocalDate(2026, 10, 1)) == nil)
    }

    @Test func picksTheLatestReadySemester() throws {
        func term(_ name: String, _ start: LocalDate, _ end: LocalDate) -> Term {
            Term(kind: .semester, name: name, span: DateSpan(start: start, end: end))
        }
        // Back-to-back short semesters whose ready windows overlap.
        let calendar = SchoolCalendar(name: "Short", terms: [
            term("B", LocalDate(2026, 10, 1), LocalDate(2026, 10, 20)),
            term("A", LocalDate(2026, 9, 8), LocalDate(2026, 9, 30)),
        ], breaks: [])

        #expect(CafeWrapped.semester(in: calendar, on: LocalDate(2026, 10, 10))?.name == "A") // only A is ready
        #expect(CafeWrapped.semester(in: calendar, on: LocalDate(2026, 10, 18))?.name == "B") // both are
    }

    @Test func announcesFallFromDecember12ThroughJanuary8() {
        let window = DateSpan(start: LocalDate(2026, 12, 12), end: LocalDate(2027, 1, 8))
        var day = LocalDate(2026, 11, 30)
        while day <= LocalDate(2027, 1, 31) {
            let semester = CafeWrapped.semester(in: calendar, on: day)
            #expect(semester.map { CafeWrapped.isReady($0, on: day) } == window.contains(day), "\(day)")
            if window.contains(day) {
                #expect(semester?.name == "Fall Semester", "\(day)")
            }
            day = day.adding(days: 1)
        }
    }

    @Test func isReadyAroundTheSemesterEnd() throws {
        let fall = try fall() // ends Fri Dec 18

        #expect(!CafeWrapped.isReady(fall, on: LocalDate(2026, 12, 11)))
        #expect(CafeWrapped.isReady(fall, on: LocalDate(2026, 12, 12)))
        #expect(CafeWrapped.isReady(fall, on: LocalDate(2026, 12, 18)))
        #expect(CafeWrapped.isReady(fall, on: LocalDate(2027, 1, 8)))
        #expect(!CafeWrapped.isReady(fall, on: LocalDate(2027, 1, 9)))
    }

    @Test func namesPeriods() {
        func name(_ start: LocalDate) -> String {
            CafeWrapped.periodName(for: DateSpan(start: start, end: start.adding(days: 100)))
        }

        #expect(name(LocalDate(2026, 9, 8)) == "Fall 2026")
        #expect(name(LocalDate(2027, 1, 4)) == "Spring 2027")
        #expect(name(LocalDate(2026, 7, 1)) == "Fall 2026")
        #expect(name(LocalDate(2027, 6, 30)) == "Spring 2027")
    }

    @Test func recognizesCafes() {
        let cafes = [
            "Cafe 2000", "Cafe at Gleason Hall", "Cafe2000", "CAFÉ", "Gleason Hall Snack Bar", "Snacks", "Coffee Shop",
            "The Coffee Bar", "Grill", "Bar & Grille", "Deli Counter", "Kitchen",
        ]
        for store in cafes {
            #expect(CafeWrapped.isCafe(store), "\(store)")
        }
        let others = [
            "Athletic Store", "Athletic Store Snack Bar", "Athletics Cafe", "Bookstore", "School Store", "Delivery",
            "Kitchenware", "",
        ]
        for store in others {
            #expect(!CafeWrapped.isCafe(store), "\(store)")
        }
    }

    // MARK: Real-shaped data

    @Test func recapsTheChargesFixture() throws {
        let statement = try StoreService.parse(Fixture.data("synthetic-store-charges.json"), fetchedAt: .now)
        let asOf = LocalDate(2026, 11, 10)
        let wrapped = try #require(CafeWrapped(statement: statement, semester: try fall(), calendar: calendar, asOf: asOf))

        #expect(wrapped.total == Self.money("118.50"))
        #expect(wrapped.purchaseCount == 26) // every charge but the three athletic ones
        #expect(wrapped.itemCount == 28)
        #expect(wrapped.dayCount == 20)
        #expect(wrapped.distinctItemCount == 14)
        #expect(wrapped.cafes.map(\.name) == [Self.gleason, Self.cafe2000])
        #expect(wrapped.cafes.map(\.total) == [Self.money("107.00"), Self.money("11.50")])
        #expect(wrapped.topItems.map(\.name) == [
            "Turkey & Swiss Panini", "Grilled Chicken Caesar Wrap with Parmesan",
            "Spinach, Feta & Egg White Breakfast Wrap", "Iced Latte", "Chai Latte",
        ])
        #expect(wrapped.topItems.map(\.count) == [4, 3, 3, 3, 2])
        #expect(wrapped.months.map(\.total) == ["33.00", "54.00", "31.50"].map(Self.money))
        // Stamped in UTC on both sides of the daylight saving change, read as school time: Gleason
        // in the morning, Cafe 2000 in the afternoon.
        let hours = [8: 3, 9: 8, 10: 11, 15: 2, 16: 1, 17: 1]
        #expect(wrapped.hourCounts == (0..<24).map { hours[$0] ?? 0 })
        #expect(wrapped.peakHour == 10)
        #expect(wrapped.timeOfDay == .morning)
        #expect(wrapped.weekdayCounts == [0, 6, 4, 5, 4, 7, 0])
        #expect(wrapped.favoriteWeekday == 6) // Friday
        #expect(wrapped.biggestDay == CafeWrapped.Day(date: LocalDate(2026, 11, 2), total: Self.money("15.00"), itemCount: 3))
        #expect(wrapped.biggestPurchase?.id == 441008) // the first $6.75 wrap
        #expect(wrapped.longestStreak == Self.streak(LocalDate(2026, 9, 30), LocalDate(2026, 10, 2), 3))
        #expect(wrapped.firstPurchase?.id == 433123)
        #expect(wrapped.persona == .explorer)
    }

    // MARK: Sample

    @Test func sampleIsDeterministic() throws {
        let span = try fall().span
        let fetchedAt = span.end.at(hour: 23)
        let sample = StoreStatement.wrappedSample(semester: span, through: span.end, fetchedAt: fetchedAt)

        #expect(sample == StoreStatement.wrappedSample(semester: span, through: span.end, fetchedAt: fetchedAt))
        #expect(sample.charges.count == 138)
        #expect(sample.grandTotal == Self.money("591.13"))
        #expect(sample.stores == ["Athletic Store", Self.cafe2000, Self.gleason])
        #expect(sample.charges.first?.id == 452_317)
        #expect(Set(sample.charges.map(\.id)).count == sample.charges.count)
        #expect(zip(sample.charges, sample.charges.dropFirst()).allSatisfy { $0.id > $1.id }) // falling with age

        // School days only; at the cafes, real menu items at their prices, while the cafe is open.
        for charge in sample.charges {
            #expect(calendar.isSchoolDay(LocalDate(charge.madeAt)))
        }
        for charge in sample.charges where CafeWrapped.isCafe(charge.storeName) {
            #expect(CafeMenus.isOnMenu(charge), "\(charge.detail)")
            #expect(CafeMenus.isDuringHours(charge), "\(charge.detail) \(charge.madeAt)")
        }

        let athletic = sample.charges(in: ["Athletic Store"])
        #expect(athletic.count == 4)
        #expect(athletic.allSatisfy { (20...60).contains($0.amount) })
    }

    @Test func sampleCutShortIsTheStartOfTheFullOne() throws {
        let span = try fall().span
        let through = LocalDate(2026, 11, 10)
        let full = StoreStatement.wrappedSample(semester: span, through: span.end, fetchedAt: span.end.at(hour: 23))
        let soFar = StoreStatement.wrappedSample(semester: span, through: through, fetchedAt: through.at(hour: 23))

        func purchases(_ charges: [StoreCharge]) -> [String] {
            charges.map { "\($0.storeName) \($0.detail) \($0.quantity) \($0.total) \($0.madeAt)" }
        }
        #expect(purchases(soFar.charges) == purchases(full.charges.filter { LocalDate($0.madeAt) <= through }))
        #expect(soFar.charges.first?.id == 452_317)
        #expect(soFar.charges.filter(\.isPending).allSatisfy { LocalDate($0.madeAt) == through })

        let recap = try #require(CafeWrapped(statement: soFar, semester: try fall(), calendar: calendar, asOf: through))
        #expect(!recap.period.isComplete)
        #expect(recap.period.through == through)
    }

    @Test func sampleRecapHeadlines() throws {
        let wrapped = CafeWrapped.sample

        #expect(wrapped.period.name == "Fall 2026")
        #expect(wrapped.period.isComplete)
        #expect(wrapped.total == Self.money("423.75"))
        #expect(wrapped.purchaseCount == 134)
        #expect(wrapped.itemCount == 142)
        #expect(wrapped.dayCount == 54)
        #expect(wrapped.days.count == 54)
        #expect(wrapped.days.first?.date == LocalDate(2026, 9, 8))
        #expect(wrapped.distinctItemCount == 43)
        #expect(wrapped.averagePerDay == Self.money("7.85"))
        #expect(wrapped.cafes.map(\.name) == [Self.gleason, Self.cafe2000])
        #expect(wrapped.cafes.map(\.total) == [Self.money("221.00"), Self.money("202.75")])
        // Gleason on most weekdays, Cafe 2000 on Wednesdays and Thursdays.
        #expect(wrapped.cafes.map(\.weekdayTotals) == [
            ["0", "41.50", "55.00", "31.00", "56.25", "37.25", "0"].map(Self.money),
            ["0", "28.00", "37.25", "54.50", "64.00", "19.00", "0"].map(Self.money),
        ])
        // Fifteen weeks from Sep 7, Thanksgiving week (the twelfth) nearly empty.
        #expect(wrapped.weekStarts.count == 15)
        #expect(wrapped.weekStarts.last == LocalDate(2026, 12, 14))
        #expect(wrapped.cafes.map { $0.weeklyTotals[11] } == [Self.money("2.00"), 0])
        #expect(wrapped.topItems.map(\.name) == [
            "Jumbo Chocolate Chip Cookie", "Body Armor", "Doritos", "Chicken Tenders", "Pepperoni Pizza",
        ])
        #expect(wrapped.topItems.map(\.count) == [30, 16, 11, 8, 5])
        #expect(wrapped.topItems.map(\.emoji) == ["🍪", "🥤", "🌽", "🍗", "🍕"])
        #expect(wrapped.topItems.map(\.productImage) == [nil, "product-bodyarmor", "product-doritos", nil, nil])
        #expect(wrapped.months.map(\.name) == ["Sep", "Oct", "Nov", "Dec"])
        // Mornings at Gleason, afternoons at Cafe 2000.
        #expect(wrapped.peakHour == 10)
        #expect(wrapped.favoriteWeekday == 5) // Thursday
        #expect(wrapped.timeOfDay == .morning)
        #expect(wrapped.share(ofHours: CafeTimeOfDay.afternoon.hours) > 0.25)
        #expect(wrapped.biggestDay == CafeWrapped.Day(date: LocalDate(2026, 10, 15), total: Self.money("29.00"), itemCount: 9))
        let biggest = try #require(wrapped.biggestPurchase)
        #expect(biggest.detail == "Cheese Pizza")
        #expect(biggest.quantity == 2)
        #expect(biggest.total == Self.money("12.00"))
        #expect(wrapped.longestStreak == Self.streak(LocalDate(2026, 10, 13), LocalDate(2026, 10, 26), 10))
        #expect(wrapped.firstPurchase?.detail == "Nestle Hot Cocoa")
        #expect(wrapped.persona == .regular)
    }
}
