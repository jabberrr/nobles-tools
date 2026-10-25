import SwiftUI
import WidgetKit
import NoblesKit

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.countdown.timelineKind,
            intent: CountdownWidgetIntent.self,
            provider: CountdownTimelineProvider()
        ) { entry in
            WidgetChrome(design: entry.design) { family, colors in
                CountdownWidgetView(design: entry.design, family: family, colors: colors, snapshot: entry.snapshot)
            }
        }
        .configurationDisplayName(WidgetKind.countdown.displayName)
        .description(WidgetKind.countdown.summary)
        .supportedFamilies(WidgetKind.countdown.widgetFamilies)
    }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    let snapshot: CountdownSnapshot

    /// The countdown as it stands on `day`, shown from `date`.
    init(date: Date, day: LocalDate, design: WidgetDesign, calendar: SchoolCalendar) {
        self.date = date
        self.design = design
        snapshot = CountdownSnapshot(
            configuration: design.countdownConfiguration ?? CountdownConfiguration(),
            calendar: calendar,
            date: day
        )
    }
}

struct CountdownTimelineProvider: AppIntentTimelineProvider {
    /// Days of entries per timeline. Countdowns are computed locally, so this only bounds the work.
    private static let days = 7

    func placeholder(in context: Context) -> CountdownEntry {
        let now = Date.now
        return CountdownEntry(date: now, day: LocalDate(now), design: .makeDefault(.countdown), calendar: .nobles2026_27)
    }

    func snapshot(for configuration: CountdownWidgetIntent, in context: Context) async -> CountdownEntry {
        let store = DesignStore()
        let design = store.resolvedDesign(id: configuration.design?.id, kind: .countdown)
        let now = Date.now
        return CountdownEntry(date: now, day: LocalDate(now), design: design, calendar: store.calendar())
    }

    /// One entry now and one at each midnight (school time) for the next week.
    func timeline(for configuration: CountdownWidgetIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let store = DesignStore()
        let design = store.resolvedDesign(id: configuration.design?.id, kind: .countdown)
        let calendar = store.calendar()
        let now = Date.now
        let today = LocalDate(now)
        let entries = (0...Self.days).map { offset in
            let day = today.adding(days: offset)
            return CountdownEntry(date: offset == 0 ? now : day.startOfDay(), day: day, design: design, calendar: calendar)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

#Preview(as: .systemSmall) {
    CountdownWidget()
} timeline: {
    CountdownEntry(date: .now, day: .today(), design: .makeDefault(.countdown), calendar: .nobles2026_27)
}
