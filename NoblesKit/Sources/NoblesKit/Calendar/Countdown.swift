import Foundation

extension SchoolCalendar {
    /// A weekday inside the school year (when the calendar has one) that isn't a break.
    public func isSchoolDay(_ date: LocalDate) -> Bool {
        !date.isWeekend
            && year?.span.contains(date) != false
            && !breaks.contains { $0.span.contains(date) }
    }

    /// Days in `span`, inclusive, that count under `counting`.
    public func countedDays(in span: DateSpan, counting: DayCounting) -> Int {
        guard span.start <= span.end else { return 0 }
        if counting == .calendarDays {
            return span.start.days(until: span.end) + 1
        }
        var count = 0
        var day = span.start
        while day <= span.end {
            if counting == .weekdays ? !day.isWeekend : isSchoolDay(day) {
                count += 1
            }
            day = day.adding(days: 1)
        }
        return count
    }

    /// The countdown to the end of the current term of `kind` on `date`; `nil` if the calendar
    /// has no such term. `remaining` counts days after `date`, so it's 0 on the last day. Before
    /// the term starts it's the term's full length; once every term of `kind` is over, it's 0.
    public func countdown(to kind: Term.Kind, on date: LocalDate, counting: DayCounting) -> Countdown? {
        guard let term = currentTerm(of: kind, on: date) else { return nil }
        let total = countedDays(in: term.span, counting: counting)
        let (phase, remaining): (Countdown.Phase, Int) =
            if date < term.span.start {
                (.upcoming, total)
            } else if date > term.span.end {
                (.finished, 0)
            } else {
                (
                    date == term.span.end ? .lastDay : .inProgress,
                    countedDays(in: DateSpan(start: date.adding(days: 1), end: term.span.end), counting: counting)
                )
            }
        return Countdown(term: term, phase: phase, remaining: remaining, total: total, counting: counting)
    }

    /// The term of `kind` containing `date`, else the next one to start, else the last one.
    public func currentTerm(of kind: Term.Kind, on date: LocalDate) -> Term? {
        let terms = terms.filter { $0.kind == kind }.sorted { $0.span.start < $1.span.start }
        return terms.first { $0.span.contains(date) } ?? terms.first { $0.span.start > date } ?? terms.last
    }
}
