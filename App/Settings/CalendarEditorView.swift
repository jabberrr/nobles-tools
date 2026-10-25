import SwiftUI
import NoblesKit

/// Edits the school calendar's term dates and breaks, which every countdown uses.
struct CalendarEditorView: View {
    @Environment(DesignLibrary.self) private var library
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            if !library.hasCustomCalendar {
                Section {
                    Label(SchoolCalendar.builtInNote, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Term.Kind.allCases) { kind in
                let terms = library.calendar.terms.filter { $0.kind == kind }
                if !terms.isEmpty {
                    Section(Self.sectionTitle(for: kind)) {
                        ForEach(terms) { term in
                            TermEditor(term: binding(for: term))
                        }
                    }
                }
            }

            Section {
                ForEach(library.calendar.breaks) { schoolBreak in
                    BreakEditor(schoolBreak: binding(for: schoolBreak))
                }
                .onDelete(perform: deleteBreaks)
                Button(action: addBreak) {
                    Label("Add Break", systemImage: "plus")
                }
            } header: {
                Text("Breaks")
            } footer: {
                Text("No-school days and vacations. School-day countdowns skip them.")
            }

            if library.hasCustomCalendar {
                Section {
                    Button("Reset to Built-in Dates", role: .destructive) {
                        isConfirmingReset = true
                    }
                }
            }
        }
        .navigationTitle("School Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.timeZone, .school)
        .confirmationDialog("Reset the calendar?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset to Built-in Dates", role: .destructive) {
                library.resetCalendar()
            }
        } message: {
            Text("Your edited dates and breaks will be replaced with the built-in \(library.calendar.name) calendar.")
        }
    }

    private static func sectionTitle(for kind: Term.Kind) -> String {
        switch kind {
        case .quarter: "Quarters"
        case .semester: "Semesters"
        case .year: "School Year"
        }
    }

    // MARK: Editing

    private func binding(for term: Term) -> Binding<Term> {
        Binding {
            library.calendar.terms.first { $0.id == term.id } ?? term
        } set: { newValue in
            var calendar = library.calendar
            guard let index = calendar.terms.firstIndex(where: { $0.id == newValue.id }) else { return }
            calendar.terms[index] = newValue
            library.updateCalendar(calendar)
        }
    }

    private func binding(for schoolBreak: SchoolBreak) -> Binding<SchoolBreak> {
        Binding {
            library.calendar.breaks.first { $0.id == schoolBreak.id } ?? schoolBreak
        } set: { newValue in
            var calendar = library.calendar
            guard let index = calendar.breaks.firstIndex(where: { $0.id == newValue.id }) else { return }
            calendar.breaks[index] = newValue
            library.updateCalendar(calendar)
        }
    }

    private func addBreak() {
        var calendar = library.calendar
        let today = LocalDate.today()
        calendar.breaks.append(SchoolBreak(name: "New Break", span: DateSpan(start: today, end: today)))
        library.updateCalendar(calendar)
    }

    private func deleteBreaks(at offsets: IndexSet) {
        var calendar = library.calendar
        calendar.breaks.remove(atOffsets: offsets)
        library.updateCalendar(calendar)
    }
}

private struct TermEditor: View {
    @Binding var term: Term

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(term.name)
                .font(.headline)
            DatePicker("Starts", selection: $term.span.startDate, displayedComponents: .date)
            DatePicker("Ends", selection: $term.span.endDate, in: term.span.start.pickerDate..., displayedComponents: .date)
        }
        .padding(.vertical, 2)
    }
}

private struct BreakEditor: View {
    @Binding var schoolBreak: SchoolBreak

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $schoolBreak.name)
                .font(.headline)
            DatePicker("Starts", selection: $schoolBreak.span.startDate, displayedComponents: .date)
            DatePicker("Ends", selection: $schoolBreak.span.endDate, in: schoolBreak.span.start.pickerDate..., displayedComponents: .date)
        }
        .padding(.vertical, 2)
    }
}
