import Foundation
import NoblesKit

/// Everything a countdown widget shows on one day, computed from the school calendar.
struct CountdownSnapshot: Hashable, Sendable {
    var date: LocalDate
    var target: Term.Kind
    /// One countdown per kind of term the calendar has, ordered quarter, semester, year.
    var countdowns: [Countdown]
    /// The break in progress, or the next one to start.
    var nextBreak: SchoolBreak?

    init(configuration: CountdownConfiguration, calendar: SchoolCalendar, date: LocalDate) {
        self.date = date
        target = configuration.target
        countdowns = Term.Kind.allCases.compactMap {
            calendar.countdown(to: $0, on: date, counting: configuration.counting)
        }
        nextBreak = calendar.breaks
            .filter { $0.span.end >= date }
            .min { $0.span.start < $1.span.start }
    }

    /// The countdown the design asked for.
    var primary: Countdown? { countdowns.first { $0.term.kind == target } }

    /// The other kinds of term, for the larger sizes.
    var others: [Countdown] { countdowns.filter { $0.term.kind != target } }

    /// "In 26 days · Nov 25 – 29", or "Now · through Nov 29" during the break.
    func timingText(of schoolBreak: SchoolBreak) -> String {
        if schoolBreak.span.contains(date) {
            return "Now · through \(SchoolFormat.shortDate(schoolBreak.span.end))"
        }
        let days = date.days(until: schoolBreak.span.start)
        let when = days == 1 ? "Tomorrow" : "In \(days) days"
        return "\(when) · \(SchoolFormat.span(schoolBreak.span))"
    }
}

extension Countdown {
    /// Whether there are still days to count (as opposed to the last day, or all done).
    var isCounting: Bool { phase == .upcoming || phase == .inProgress }

    /// The headline: the count, or a word once there's nothing left to count.
    var figure: String {
        switch phase {
        case .upcoming, .inProgress: "\(remaining)"
        case .lastDay: "Last day"
        case .finished: "Done"
        }
    }

    /// The unit under a count: "school days left" during the term, "school days" (its length)
    /// before it starts.
    var unitText: String {
        let unit = SchoolFormat.unit(counting, count: remaining)
        return phase == .inProgress ? "\(unit) left" : unit
    }

    /// The line under the figure, e.g. "school days left" or "school days · starts Jan 25".
    var caption: String {
        let unit = SchoolFormat.unit(counting, count: remaining)
        switch phase {
        case .upcoming: return "\(unit) · starts \(SchoolFormat.shortDate(term.span.start))"
        case .inProgress: return "\(unit) left"
        case .lastDay: return "of \(term.name)"
        case .finished: return "\(term.name) ended \(SchoolFormat.shortDate(term.span.end))"
        }
    }

    /// One short line for the inline Lock Screen widget, e.g. "42 school days left in Q2". The
    /// year needs no name: "150 school days left".
    var sentence: String {
        let unit = SchoolFormat.unit(counting, count: remaining)
        let isYear = term.kind == .year
        let name = term.compactName
        switch phase {
        case .upcoming: return "\(isYear ? "School" : name) starts \(SchoolFormat.shortDate(term.span.start))"
        case .inProgress: return isYear ? "\(remaining) \(unit) left" : "\(remaining) \(unit) left in \(name)"
        case .lastDay: return isYear ? "Last day of school!" : "Last day of \(name)!"
        case .finished: return isYear ? "School's out!" : "\(name) is done"
        }
    }

    /// "63% complete · ends Fri, Jan 22", "Starts Mon, Sep 8", …
    var progressText: String {
        switch phase {
        case .upcoming: "Starts \(SchoolFormat.weekdayDate(term.span.start))"
        case .inProgress: "\(percentComplete) complete · ends \(SchoolFormat.weekdayDate(term.span.end))"
        case .lastDay: "Last day today"
        case .finished: "Ended \(SchoolFormat.weekdayDate(term.span.end))"
        }
    }

    /// Whole percent of the term completed, e.g. "63%".
    var percentComplete: String { "\(Int((progress * 100).rounded()))%" }
}

extension Term {
    /// A short name for tight spaces: "Quarter 2" becomes "Q2", "Fall Semester" becomes "Fall",
    /// and the year is "Year". Names in another form are kept as they are.
    var compactName: String {
        switch kind {
        case .quarter:
            name.hasPrefix("Quarter ") ? "Q" + name.dropFirst("Quarter ".count) : name
        case .semester:
            name.hasSuffix(" Semester") ? String(name.dropLast(" Semester".count)) : name
        case .year:
            "Year"
        }
    }
}
