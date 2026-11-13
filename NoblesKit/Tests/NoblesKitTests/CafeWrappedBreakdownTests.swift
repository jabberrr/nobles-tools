import Foundation
import Testing
@testable import NoblesKit

struct CafeWrappedBreakdownTests {
    private typealias Breakdown = CafeWrapped.CafeBreakdown

    private static func money(_ amount: String) -> Decimal {
        Decimal(string: amount) ?? .nan
    }

    /// A cafe with what it spent each weekday (Sunday first) and each week.
    private static func cafe(_ name: String, share: Double = 0.2, weekdays: [String], weeks: [String]) -> CafeWrapped.Cafe {
        let weekdayTotals = weekdays.map(money)
        return CafeWrapped.Cafe(
            name: name,
            total: weekdayTotals.reduce(0, +),
            purchaseCount: 1,
            dayCount: 1,
            share: share,
            weekdayTotals: weekdayTotals,
            weeklyTotals: weeks.map(money)
        )
    }

    /// Mondays from Sep 7, 2026.
    private static func weekStarts(_ count: Int) -> [LocalDate] {
        (0..<count).map { LocalDate(2026, 9, 7).adding(days: 7 * $0) }
    }

    /// Five cafes, most spent first, over two weeks.
    private static let fiveCafes = [
        cafe("A", share: 0.4, weekdays: ["0", "5", "4", "0", "0", "0", "0"], weeks: ["6", "3"]),
        cafe("B", share: 0.3, weekdays: ["0", "1", "2", "3", "0", "0", "0"], weeks: ["4", "2"]),
        cafe("C", share: 0.2, weekdays: ["0", "0", "0", "0", "2", "2", "0"], weeks: ["0", "4"]),
        cafe("D", share: 0.06, weekdays: ["0", "0", "0", "0", "0", "1", "1"], weeks: ["2", "0"]),
        cafe("E", share: 0.04, weekdays: ["0", "0", "0", "0", "2", "0", "0"], weeks: ["0", "1"]),
    ]

    @Test func keepsThreeCafesApartAndGroupsTheRest() {
        let breakdown = Breakdown(cafes: Self.fiveCafes, weekStarts: Self.weekStarts(2))

        #expect(breakdown.cafes.map(\.cafeNames) == [["A"], ["B"], ["C"]])
        #expect(breakdown.cafes.map(\.total) == [9, 6, 4])
        let others = breakdown.others
        #expect(others?.cafeNames == ["D", "E"])
        #expect(others?.total == 4)
        #expect(abs((others?.share ?? 0) - 0.1) < 1e-9)
        #expect(breakdown.groups.map(\.id) == ["A", "B", "C", "D\nE"])

        // Each column stacks the groups in order, the others added together.
        #expect(breakdown.weeks.map(\.spent) == [[6, 4, 0, 2], [3, 2, 4, 1]])
        #expect(breakdown.weeks.map(\.start) == Self.weekStarts(2))
    }

    @Test func namesTheOnlyOtherCafe() {
        let breakdown = Breakdown(cafes: Array(Self.fiveCafes.prefix(4)), weekStarts: Self.weekStarts(2))

        #expect(breakdown.others?.cafeNames == ["D"])
        #expect(breakdown.groups.count == 4)
    }

    @Test func hasNoOthersWithThreeCafesOrFewer() {
        let three = Breakdown(cafes: Array(Self.fiveCafes.prefix(3)), weekStarts: Self.weekStarts(2))
        #expect(three.others == nil)
        #expect(three.groups.count == 3)

        let one = Breakdown(cafes: [Self.fiveCafes[0]], weekStarts: Self.weekStarts(2))
        #expect(one.cafes.map(\.cafeNames) == [["A"]])
        #expect(one.weekdays.map(\.spent) == [[5], [4], [0], [0], [0]])
    }

    @Test func showsWeekdaysThenWeekendDaysWithSpending() {
        let breakdown = Breakdown(cafes: Self.fiveCafes, weekStarts: Self.weekStarts(2))

        // Saturday has D's spending; nothing on Sunday.
        #expect(breakdown.weekdays.map(\.weekday) == [2, 3, 4, 5, 6, 7])
        #expect(breakdown.weekdays.map(\.spent) == [
            [5, 1, 0, 0], [4, 2, 0, 0], [0, 3, 0, 0], [0, 0, 2, 2], [0, 0, 2, 1], [0, 0, 0, 1],
        ])
        #expect(breakdown.weekdays.map(\.total) == [6, 6, 3, 4, 3, 1])
        // Thursday's tie goes to the earlier group.
        #expect(breakdown.weekdays.map(\.leader) == [0, 0, 1, 2, 2, 3])
    }

    @Test func refundsStackAsNothing() {
        let cafes = [
            Self.cafe("A", weekdays: ["-2", "3", "-1", "0", "0", "0", "0"], weeks: ["4", "-4"]),
            Self.cafe("B", weekdays: ["0", "1", "2", "0", "0", "0", "0"], weeks: ["-1", "0"]),
        ]
        let breakdown = Breakdown(cafes: cafes, weekStarts: Self.weekStarts(2))

        // A Sunday with only a refund isn't shown; a refund adds nothing to a column's height.
        #expect(breakdown.weekdays.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(breakdown.weekdays.map(\.total) == [4, 2, 0, 0, 0])
        #expect(breakdown.weekdays.map(\.leader) == [0, 1, nil, nil, nil])
        #expect(breakdown.weeks.map(\.total) == [4, 0])
        #expect(breakdown.biggestWeek?.start == LocalDate(2026, 9, 7))
    }

    @Test func findsTheBiggestWeekdayAndWeekEarliestFirst() {
        let cafes = [Self.cafe("A", weekdays: ["0", "2", "3", "3", "0", "0", "0"], weeks: ["1", "5", "5"])]
        let breakdown = Breakdown(cafes: cafes, weekStarts: Self.weekStarts(3))

        #expect(breakdown.biggestWeekday?.weekday == 3) // Tuesday before Wednesday
        #expect(breakdown.biggestWeek?.start == LocalDate(2026, 9, 14))

        let nothing = Breakdown(cafes: [Self.cafe("A", weekdays: Array(repeating: "0", count: 7), weeks: ["0"])], weekStarts: Self.weekStarts(1))
        #expect(nothing.biggestWeekday == nil)
        #expect(nothing.biggestWeek == nil)
    }

    @Test func namesMonthsUnderTheWeeksTheyStart() {
        func months(from start: LocalDate, weeks: Int) -> [Int?] {
            let starts = (0..<weeks).map { start.adding(days: 7 * $0) }
            let cafe = Self.cafe("A", weekdays: Array(repeating: "0", count: 7), weeks: Array(repeating: "0", count: weeks))
            return Breakdown(cafes: [cafe], weekStarts: starts).weeks.map(\.month)
        }

        // Fall 2026: each by its Thursday, so the week of Mon Sep 28 is October's.
        #expect(months(from: LocalDate(2026, 9, 7), weeks: 15) == [
            9, nil, nil, 10, nil, nil, nil, nil, 11, nil, nil, nil, 12, nil, nil,
        ])
        // October starts a week in, so September's name is left off.
        #expect(months(from: LocalDate(2026, 9, 21), weeks: 3) == [nil, 10, nil])
        // One month throughout.
        #expect(months(from: LocalDate(2026, 10, 5), weeks: 2) == [10, nil])
    }

    @Test func breaksDownTheSample() throws {
        let breakdown = CafeWrapped.sample.cafeBreakdown

        #expect(breakdown.cafes.map(\.cafeNames) == [["Cafe at Gleason Hall"], ["Cafe 2000"]])
        #expect(breakdown.others == nil)
        #expect(breakdown.weekdays.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(breakdown.weekdays.map(\.leader) == [0, 0, 1, 1, 0]) // Cafe 2000 on Wednesdays and Thursdays
        let thursday = try #require(breakdown.biggestWeekday)
        #expect(thursday.weekday == 5)
        #expect(thursday.total == Self.money("120.25"))
        let week = try #require(breakdown.biggestWeek)
        #expect(week.start == LocalDate(2026, 10, 19))
        #expect(week.total == Self.money("66.50"))
        #expect(breakdown.weeks.compactMap(\.month) == [9, 10, 11, 12])
    }
}
