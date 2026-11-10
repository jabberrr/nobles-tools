import Foundation
import NoblesKit

/// Wrapped's figures and dates as text. Dates and times are in school time, whatever the device's
/// time zone.
enum WrappedFormat {
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// "$612.75", for a counting figure: as `Decimal.usd()` writes it, but with a format made once,
    /// since a count asks for it every frame.
    static func dollars(_ value: Double) -> String {
        dollarFormat.format(value)
    }

    private static let dollarFormat = FloatingPointFormatStyle<Double>.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        .rounded(rule: .toNearestOrAwayFromZero)

    /// A count of whole things as it counts up: "168".
    static func whole(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }

    /// "1 purchase", "168 purchases".
    static func count(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        let noun = count == 1 ? singular : (plural ?? "\(singular)s")
        return "\(count.formatted()) \(noun)"
    }

    /// "18%".
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// "Fall 2026", or "Fall 2026 · So far" while the semester is still going.
    static func period(_ period: CafeWrapped.Period) -> String {
        period.isComplete ? period.name : "\(period.name) · So far"
    }

    /// "Tue, Sep 8".
    static func day(_ date: LocalDate) -> String {
        "\(shortWeekday(date.weekday)), \(shortDay(date))"
    }

    /// "Sep 8".
    static func shortDay(_ date: LocalDate) -> String {
        "\(shortMonth(date.month)) \(date.day)"
    }

    /// "Sep", for a month 1...12.
    static func shortMonth(_ month: Int) -> String {
        Calendar.school.shortMonthSymbols[month - 1]
    }

    /// "September", for a month 1...12.
    static func month(_ month: Int) -> String {
        Calendar.school.monthSymbols[month - 1]
    }

    /// "Oct 5 to Oct 16", noting when the run skipped days off: only a missed school day ends it.
    static func streakDates(_ streak: CafeWrapped.Streak) -> String {
        let span = "\(shortDay(streak.start)) to \(shortDay(streak.end))"
        let days = streak.start.days(until: streak.end) + 1
        return days > streak.length ? "\(span), school days only" : span
    }

    /// "Tuesday", for a `Calendar` weekday 1...7.
    static func weekday(_ weekday: Int) -> String {
        Calendar.school.weekdaySymbols[weekday - 1]
    }

    /// "Tue", for a `Calendar` weekday 1...7.
    static func shortWeekday(_ weekday: Int) -> String {
        Calendar.school.shortWeekdaySymbols[weekday - 1]
    }

    /// "10 AM", "12 PM".
    static func hour(_ hour: Int) -> String {
        "\(twelveHour(hour)) \(meridiem(hour))"
    }

    /// "10a", "12p": chart axis labels.
    static func compactHour(_ hour: Int) -> String {
        "\(twelveHour(hour))\(hour % 24 < 12 ? "a" : "p")"
    }

    /// The hour starting at `hour`, for "between …": "10 and 11 AM", "11 AM and 12 PM".
    static func hourSpan(_ hour: Int) -> String {
        let end = hour + 1
        guard meridiem(hour) == meridiem(end) else {
            return "\(Self.hour(hour)) and \(Self.hour(end))"
        }
        return "\(twelveHour(hour)) and \(twelveHour(end)) \(meridiem(end))"
    }

    /// "10:42 AM".
    private static func time(_ date: Date) -> String {
        let parts = Calendar.school.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return "\(twelveHour(hour)):\(minute < 10 ? "0" : "")\(minute) \(meridiem(hour))"
    }

    /// "Tue, Sep 8 at 10:42 AM".
    static func moment(_ date: Date) -> String {
        "\(day(LocalDate(date))) at \(time(date))"
    }

    private static func twelveHour(_ hour: Int) -> Int {
        let value = hour % 12
        return value == 0 ? 12 : value
    }

    private static func meridiem(_ hour: Int) -> String {
        hour % 24 < 12 ? "AM" : "PM"
    }
}
