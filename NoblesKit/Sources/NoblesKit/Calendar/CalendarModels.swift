import Foundation

/// A school year: its grading periods and the days with no classes.
/// Ships with the published Nobles calendar and can be edited in the app.
public struct SchoolCalendar: Codable, Hashable, Sendable {
    /// e.g. "2026–27"
    public var name: String
    public var terms: [Term]
    /// No-school days and vacations, inclusive.
    public var breaks: [SchoolBreak]

    public init(name: String, terms: [Term], breaks: [SchoolBreak]) {
        self.name = name
        self.terms = terms
        self.breaks = breaks
    }

    /// The year-long term, if present.
    public var year: Term? { terms.first { $0.kind == .year } }
}

public struct Term: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: Term.Kind
    /// e.g. "Fall Semester", "Quarter 3"
    public var name: String
    public var span: DateSpan

    public init(id: UUID = UUID(), kind: Term.Kind, name: String, span: DateSpan) {
        self.id = id
        self.kind = kind
        self.name = name
        self.span = span
    }

    public enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case quarter
        case semester
        case year

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .quarter: "Quarter"
            case .semester: "Semester"
            case .year: "School Year"
            }
        }
    }
}

public struct SchoolBreak: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var span: DateSpan

    public init(id: UUID = UUID(), name: String, span: DateSpan) {
        self.id = id
        self.name = name
        self.span = span
    }
}

/// How days are counted in a countdown.
public enum DayCounting: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Weekdays that aren't breaks.
    case schoolDays
    /// Monday–Friday, ignoring breaks.
    case weekdays
    /// Every day.
    case calendarDays

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .schoolDays: "School Days"
        case .weekdays: "Weekdays"
        case .calendarDays: "Calendar Days"
        }
    }

    /// Short unit label, e.g. "school days".
    public var unit: String {
        switch self {
        case .schoolDays: "school days"
        case .weekdays: "weekdays"
        case .calendarDays: "days"
        }
    }
}

public enum CountdownStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// A big number.
    case number
    /// A progress ring around the number.
    case ring
    /// A progress bar under the number.
    case bar

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .number: "Number"
        case .ring: "Ring"
        case .bar: "Bar"
        }
    }
}

public struct CountdownConfiguration: Codable, Hashable, Sendable {
    public var target: Term.Kind
    public var counting: DayCounting
    public var style: CountdownStyle

    public init(target: Term.Kind = .year, counting: DayCounting = .schoolDays, style: CountdownStyle = .ring) {
        self.target = target
        self.counting = counting
        self.style = style
    }
}

/// The computed state of a countdown on a given day.
public struct Countdown: Hashable, Sendable {
    public enum Phase: Hashable, Sendable {
        /// The term hasn't started yet; `remaining` counts its full length.
        case upcoming
        case inProgress
        /// Today is the term's last day.
        case lastDay
        /// Every term of this kind has ended.
        case finished
    }

    public var term: Term
    public var phase: Phase
    /// Counted days left after today, through the term's last day.
    public var remaining: Int
    /// Counted days in the whole term.
    public var total: Int
    public var counting: DayCounting

    public init(term: Term, phase: Phase, remaining: Int, total: Int, counting: DayCounting) {
        self.term = term
        self.phase = phase
        self.remaining = remaining
        self.total = total
        self.counting = counting
    }

    /// Fraction of the term completed, 0...1.
    public var progress: Double {
        guard total > 0 else { return phase == .finished ? 1 : 0 }
        return min(max(Double(total - remaining) / Double(total), 0), 1)
    }
}
