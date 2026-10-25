import Foundation
import Testing
@testable import NoblesKit

struct LocalDateTests {
    @Test func parsesAndFormatsISO() throws {
        let date = try #require(LocalDate(iso: "2026-10-26T00:00:00"))
        #expect(date == LocalDate(year: 2026, month: 10, day: 26))
        #expect(date.iso == "2026-10-26")
        #expect(LocalDate(iso: "2026-13-01") == nil)
    }

    @Test func arithmeticCrossesMonthAndDST() {
        let saturday = LocalDate(year: 2026, month: 10, day: 31)
        #expect(saturday.adding(days: 1) == LocalDate(year: 2026, month: 11, day: 1))
        // US daylight saving time ends 2026-11-01.
        #expect(saturday.adding(days: 2) == LocalDate(year: 2026, month: 11, day: 2))
        #expect(saturday.days(until: LocalDate(year: 2026, month: 11, day: 7)) == 7)
        #expect(saturday.isWeekend)
        #expect(saturday.weekday == 7)
    }

    @Test func roundTripsThroughCodable() throws {
        let date = LocalDate(year: 2027, month: 6, day: 4)
        let data = try JSONEncoder().encode([date])
        #expect(String(decoding: data, as: UTF8.self) == #"["2027-06-04"]"#)
        #expect(try JSONDecoder().decode([LocalDate].self, from: data) == [date])
    }
}
