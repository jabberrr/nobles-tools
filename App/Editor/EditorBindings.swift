import SwiftUI
import NoblesKit

extension MenuFilter {
    /// The filter for `style`, using `sections` for the styles that take a list of stations.
    init(style: Style, sections: [String]) {
        switch style {
        case .everything: self = .everything
        case .entreesOnly: self = .entreesOnly
        case .withoutSaladsAndSoups: self = .withoutSaladsAndSoups
        case .only: self = .only(sections: sections)
        case .excluding: self = .excluding(sections: sections)
        }
    }
}

extension MenuConfiguration {
    /// The filter's style, settable for pickers. Switching between "Just…" and "Everything
    /// Except…" keeps the chosen stations.
    var filterStyle: MenuFilter.Style {
        get { filter.style }
        set { filter = MenuFilter(style: newValue, sections: filter.selectedSections) }
    }

    /// The stations chosen for "Just…" or "Everything Except…".
    var filterSections: [String] {
        get { filter.selectedSections }
        set { filter = MenuFilter(style: filter.style, sections: newValue) }
    }
}

extension Binding where Value == DateSpan {
    /// The first day, for a `DatePicker`. Moving it past the last day moves the last day too.
    var startDate: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.start.pickerDate },
            set: { date in
                var span = wrappedValue
                span.start = LocalDate(date)
                span.end = Swift.max(span.end, span.start)
                wrappedValue = span
            }
        )
    }

    /// The last day, for a `DatePicker`; never before the first day.
    var endDate: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.end.pickerDate },
            set: { date in
                var span = wrappedValue
                span.end = Swift.max(LocalDate(date), span.start)
                wrappedValue = span
            }
        )
    }
}

extension LocalDate {
    /// Noon school time on this day: what date pickers edit, so no time-zone shift can change the day.
    var pickerDate: Date { at(hour: 12) }
}
