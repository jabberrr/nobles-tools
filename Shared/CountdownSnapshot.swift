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

    /// One line for the inline Lock Screen widget, e.g. "42 school days left in Q2".
    var sentence: String {
        let unit = SchoolFormat.unit(counting, count: remaining)
        let isYear = term.kind == .year
        switch phase {
        case .upcoming: return "\(isYear ? "School" : term.compactName) starts \(SchoolFormat.shortDate(term.span.start))"
        case .inProgress: return "\(remaining) \(unit) left in \(term.compactName)"
        case .lastDay: return "Last day of \(term.compactName)!"
        case .finished: return isYear ? "School's out!" : "\(term.compactName) is done"
        }
    }

    /// Whole percent of the term completed, e.g. "63%".
    var percentComplete: String { "\(Int((progress * 100).rounded()))%" }
}

extension Term {
    /// A short name for tight spaces: "Quarter 2" becomes "Q2"; the year reads "the year".
    var compactName: String {
        switch kind {
        case .quarter:
            guard name.hasPrefix("Quarter ") else { return name }
            return "Q" + name.dropFirst("Quarter ".count)
        case .semester:
            return name
        case .year:
            return "the year"
        }
    }
}
