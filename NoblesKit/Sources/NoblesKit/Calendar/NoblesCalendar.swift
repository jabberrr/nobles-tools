import Foundation

extension SchoolCalendar {
    /// Nobles' 2026–27 year: two semesters, each split into quarters. Only graduation (the Friday
    /// after Memorial Day) is reliable; the other dates are estimates. IDs are fixed so the
    /// built-in calendar compares equal across launches.
    public static let nobles2026_27 = SchoolCalendar(
        name: "2026–27",
        terms: [
            term("38BC3CF7-85C5-43DA-8DC1-BB9F2C065109", .year, "2026–27 School Year", from: (2026, 9, 8), to: (2027, 6, 4)),
            term("A4D41914-6309-4E81-ADCD-92DB9D16137B", .semester, "Fall Semester", from: (2026, 9, 8), to: (2026, 12, 18)),
            term("B7C4190A-1136-4DA3-84EF-0A8D0BC63903", .semester, "Spring Semester", from: (2027, 1, 4), to: (2027, 6, 4)),
            term("B2E0AE34-4C84-42DB-9802-2AFEE0C47426", .quarter, "Quarter 1", from: (2026, 9, 8), to: (2026, 10, 30)),
            term("BFD66CF2-B7EC-4DD5-BE88-B6AC2B71110D", .quarter, "Quarter 2", from: (2026, 11, 2), to: (2026, 12, 18)),
            term("E2BD232C-17B6-4965-86BE-5CB2F2945A2B", .quarter, "Quarter 3", from: (2027, 1, 4), to: (2027, 3, 12)),
            term("928F3AE4-EF4E-49F3-9290-68E50A3FA186", .quarter, "Quarter 4", from: (2027, 3, 29), to: (2027, 6, 4)),
        ],
        breaks: [
            schoolBreak("3B5AFAAD-3953-4E7B-8AC3-7AF4AB690C2C", "Indigenous Peoples' Day", from: (2026, 10, 12)),
            schoolBreak("882D9E96-1FD8-4BFB-8B6C-CEF5FA19C75B", "Thanksgiving Break", from: (2026, 11, 25), to: (2026, 11, 29)),
            schoolBreak("52F33E3C-AEDC-43E3-BB3F-D3288EF07843", "Winter Break", from: (2026, 12, 19), to: (2027, 1, 3)),
            schoolBreak("A2F2320F-9C7E-49E4-BE2E-B1B638DE422B", "Martin Luther King Jr. Day", from: (2027, 1, 18)),
            schoolBreak("7D8E7D09-0B5A-4814-BECF-BE9D0B006405", "Presidents' Day", from: (2027, 2, 15)),
            schoolBreak("38BF2D55-9086-4C86-A325-4C0548D6DD31", "March Break", from: (2027, 3, 13), to: (2027, 3, 28)),
            schoolBreak("10ED14C4-CCB3-425C-A7CA-EA542BE4C816", "Patriots' Day", from: (2027, 4, 19)),
            schoolBreak("387164AE-8651-4202-851C-8D9F0789B88E", "Memorial Day", from: (2027, 5, 31)),
        ]
    )

    /// Shown wherever the built-in calendar is used.
    public static let builtInNote = "These dates are estimates. Nobles' full calendar is only available through the family login, so check it there and correct any dates in Settings."

    private typealias Day = (year: Int, month: Int, day: Int)

    private static func term(_ id: String, _ kind: Term.Kind, _ name: String, from start: Day, to end: Day) -> Term {
        Term(id: UUID(uuidString: id)!, kind: kind, name: name, span: span(start, end))
    }

    private static func schoolBreak(_ id: String, _ name: String, from start: Day, to end: Day? = nil) -> SchoolBreak {
        SchoolBreak(id: UUID(uuidString: id)!, name: name, span: span(start, end ?? start))
    }

    private static func span(_ start: Day, _ end: Day) -> DateSpan {
        DateSpan(
            start: LocalDate(year: start.year, month: start.month, day: start.day),
            end: LocalDate(year: end.year, month: end.month, day: end.day)
        )
    }
}
