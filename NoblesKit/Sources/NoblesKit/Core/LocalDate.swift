import Foundation

extension TimeZone {
    /// Nobles is in Dedham, MA. All school dates and meal times are interpreted here,
    /// regardless of the device's time zone.
    public static let school = TimeZone(identifier: "America/New_York")!
}

extension Calendar {
    /// Gregorian calendar pinned to the school's time zone.
    public static let school: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .school
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()
}

/// A calendar day with no time or time zone attached, e.g. a menu date or the last
/// day of a term. Encodes as an ISO-8601 `yyyy-MM-dd` string.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar` (the school's calendar by default).
    public init(_ date: Date, calendar: Calendar = .school) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Parses `yyyy-MM-dd`, ignoring anything after the day (such as a time suffix).
    public init?(iso string: String) {
        let parts = string.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Today in the school's time zone.
    public static func today(now: Date = .now) -> LocalDate { LocalDate(now) }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Midnight at the start of this day in `calendar`.
    public func startOfDay(in calendar: Calendar = .school) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A time on this day in `calendar`, e.g. when lunch service ends.
    public func at(hour: Int, minute: Int = 0, in calendar: Calendar = .school) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(Calendar.school.date(byAdding: .day, value: days, to: startOfDay())!)
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    public func days(until other: LocalDate) -> Int {
        Calendar.school.dateComponents([.day], from: startOfDay(), to: other.startOfDay()).day!
    }

    /// 1 = Sunday ... 7 = Saturday, matching `Calendar.component(.weekday, ...)`.
    public var weekday: Int {
        Calendar.school.component(.weekday, from: startOfDay())
    }

    public var isWeekend: Bool { weekday == 1 || weekday == 7 }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension LocalDate: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let date = LocalDate(iso: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected yyyy-MM-dd, got \(string)")
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}

extension LocalDate: CustomStringConvertible {
    public var description: String { iso }
}

/// An inclusive range of days, e.g. a term or a vacation.
public struct DateSpan: Hashable, Codable, Sendable {
    public var start: LocalDate
    public var end: LocalDate

    public init(start: LocalDate, end: LocalDate) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: LocalDate) -> Bool {
        start <= date && date <= end
    }
}
