import Foundation
import Testing
@testable import NoblesKit

struct CountdownTests {
    /// Three weeks of school (Nov 2–20, 2026) in two quarters, with Wednesday Nov 11 off.
    private let calendar = SchoolCalendar(
        name: "Test",
        terms: [
            Term(kind: .year, name: "Year", span: DateSpan(start: LocalDate(2026, 11, 2), end: LocalDate(2026, 11, 20))),
            Term(kind: .quarter, name: "Q2", span: DateSpan(start: LocalDate(2026, 11, 16), end: LocalDate(2026, 11, 20))),
            Term(kind: .quarter, name: "Q1", span: DateSpan(start: LocalDate(2026, 11, 2), end: LocalDate(2026, 11, 13))),
        ],
        breaks: [SchoolBreak(name: "Veterans Day", span: DateSpan(start: LocalDate(2026, 11, 11), end: LocalDate(2026, 11, 11)))]
    )

    @Test func schoolDaysAreWeekdaysInTheYearOutsideBreaks() {
        #expect(calendar.isSchoolDay(LocalDate(2026, 11, 4)))
        #expect(!calendar.isSchoolDay(LocalDate(2026, 11, 7)))
        #expect(!calendar.isSchoolDay(LocalDate(2026, 11, 11)))
        #expect(!calendar.isSchoolDay(LocalDate(2026, 10, 30)))

        let noYear = SchoolCalendar(name: "No year", terms: [], breaks: [])
        #expect(noYear.isSchoolDay(LocalDate(2026, 10, 30)))
    }

    @Test(arguments: [(DayCounting.schoolDays, 6, 9), (.weekdays, 7, 10), (.calendarDays, 9, 12)])
    func countsRemainingDaysMidTerm(counting: DayCounting, remaining: Int, total: Int) throws {
        let countdown = try #require(calendar.countdown(to: .quarter, on: LocalDate(2026, 11, 4), counting: counting))

        #expect(countdown.term.name == "Q1")
        #expect(countdown.phase == .inProgress)
        #expect(countdown.remaining == remaining)
        #expect(countdown.total == total)
    }

    @Test func lastDayHasNoneRemaining() throws {
        let countdown = try #require(calendar.countdown(to: .quarter, on: LocalDate(2026, 11, 13), counting: .schoolDays))
        #expect(countdown.phase == .lastDay)
        #expect(countdown.remaining == 0)
        #expect(countdown.progress == 1)
    }

    @Test func beforeATermCountsItsFullLength() throws {
        let first = try #require(calendar.countdown(to: .quarter, on: LocalDate(2026, 10, 30), counting: .schoolDays))
        #expect(first.term.name == "Q1")
        #expect(first.phase == .upcoming)
        #expect(first.remaining == 9)

        let between = try #require(calendar.countdown(to: .quarter, on: LocalDate(2026, 11, 14), counting: .calendarDays))
        #expect(between.term.name == "Q2")
        #expect(between.phase == .upcoming)
        #expect(between.remaining == 5)
        #expect(between.progress == 0)
    }

    @Test func finishesAfterTheLastTerm() throws {
        let countdown = try #require(calendar.countdown(to: .quarter, on: LocalDate(2026, 11, 25), counting: .schoolDays))
        #expect(countdown.term.name == "Q2")
        #expect(countdown.phase == .finished)
        #expect(countdown.remaining == 0)
        #expect(countdown.total == 5)
    }

    @Test func noCountdownWithoutTermsOfThatKind() {
        #expect(calendar.countdown(to: .semester, on: LocalDate(2026, 11, 4), counting: .schoolDays) == nil)
        #expect(calendar.currentTerm(of: .semester, on: LocalDate(2026, 11, 4)) == nil)
    }

    @Test func countedDaysOfAnEmptySpanIsZero() {
        let backwards = DateSpan(start: LocalDate(2026, 11, 5), end: LocalDate(2026, 11, 4))
        #expect(calendar.countedDays(in: backwards, counting: .calendarDays) == 0)
    }

    // MARK: Built-in calendar

    @Test func builtInCalendarIsConsistent() throws {
        let nobles = SchoolCalendar.nobles2026_27
        let year = try #require(nobles.year)
        #expect(year.span.end == LocalDate(2027, 6, 4))
        #expect(year.span.end.weekday == 6)

        for term in nobles.terms {
            #expect(term.span.start <= term.span.end)
            #expect(year.span.contains(term.span.start) && year.span.contains(term.span.end))
        }
        for schoolBreak in nobles.breaks {
            #expect(year.span.contains(schoolBreak.span.start) && year.span.contains(schoolBreak.span.end))
        }
        #expect(Set(nobles.terms.map(\.id) + nobles.breaks.map(\.id)).count == nobles.terms.count + nobles.breaks.count)
        #expect(nobles.countedDays(in: year.span, counting: .schoolDays) == 166)
    }

    @Test(arguments: [(DayCounting.schoolDays, 15), (.weekdays, 18), (.calendarDays, 24)])
    func builtInCountdownSkipsThanksgiving(counting: DayCounting, remaining: Int) throws {
        let countdown = try #require(SchoolCalendar.nobles2026_27.countdown(to: .quarter, on: LocalDate(2026, 11, 24), counting: counting))
        #expect(countdown.term.name == "Quarter 2")
        #expect(countdown.remaining == remaining)
    }
}
