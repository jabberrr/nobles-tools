import Foundation
import NoblesKit

/// Date and count formatting for widgets. Everything is shown in the school's time zone, so a
/// phone set to another zone still shows the right day for a menu, term or game.
enum SchoolFormat {
    /// "Oct 19"
    static func shortDate(_ date: LocalDate) -> String {
        noon(of: date).formatted(style(.dateTime.month(.abbreviated).day()))
    }

    /// "Mon, Oct 19"
    static func weekdayDate(_ date: LocalDate) -> String {
        noon(of: date).formatted(style(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
    }

    /// "Mon"
    static func weekday(_ date: LocalDate) -> String {
        noon(of: date).formatted(style(.dateTime.weekday(.abbreviated)))
    }

    /// "Today", "Tomorrow", "Yesterday", or "Mon, Oct 19".
    static func relativeDay(_ date: LocalDate, from today: LocalDate) -> String {
        switch today.days(until: date) {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: weekdayDate(date)
        }
    }

    /// "4:00 PM"
    static func time(_ date: Date) -> String {
        date.formatted(style(.dateTime.hour().minute()))
    }

    /// "Oct 19" or "Nov 25 – 29"
    static func span(_ span: DateSpan) -> String {
        guard span.start != span.end else { return shortDate(span.start) }
        let end = span.start.month == span.end.month
            ? noon(of: span.end).formatted(style(.dateTime.day()))
            : shortDate(span.end)
        return "\(shortDate(span.start)) – \(end)"
    }

    /// "2h ago", "3d ago", or `nil` if `date` is less than a minute before `now`.
    static func age(of date: Date, now: Date) -> String? {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        switch minutes {
        case ..<1: return nil
        case ..<60: return "\(minutes)m ago"
        case ..<(48 * 60): return "\(minutes / 60)h ago"
        default: return "\(minutes / (24 * 60))d ago"
        }
    }

    /// "1 school day", "12 school days": `DayCounting.unit` made singular for a count of one.
    /// `compact` shortens school days to "sch. days", to fit a Lock Screen circle.
    static func unit(_ counting: DayCounting, count: Int, compact: Bool = false) -> String {
        let unit = compact && counting == .schoolDays ? "sch. days" : counting.unit
        return count == 1 && unit.hasSuffix("s") ? String(unit.dropLast()) : unit
    }

    /// Noon school time: safely inside the day whatever the formatter's time zone.
    private static func noon(of date: LocalDate) -> Date {
        date.at(hour: 12)
    }

    private static func style(_ base: Date.FormatStyle) -> Date.FormatStyle {
        var style = base
        style.timeZone = .school
        return style
    }
}
