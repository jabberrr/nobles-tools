import SwiftUI
import WidgetKit
import NoblesKit

struct MenuWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "MenuWidget", intent: MenuWidgetIntent.self, provider: MenuProvider()) { entry in
            WidgetChrome(design: entry.design) { family in
                MenuWidgetView(design: entry.design, family: family, upcoming: entry.upcoming, now: entry.date)
            }
        }
        .configurationDisplayName(WidgetKind.menu.displayName)
        .description(WidgetKind.menu.summary)
        .supportedFamilies(WidgetKind.menu.widgetFamilies)
    }
}

struct MenuEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    /// `nil` when the menu couldn't be loaded, even from the cache.
    let upcoming: UpcomingMenu?

    static func sample(design: WidgetDesign, date: Date = .now) -> MenuEntry {
        let selection = design.menuConfiguration?.meal ?? .lunch
        return MenuEntry(date: date, design: design, upcoming: .placeholder(for: selection, now: date))
    }
}

struct MenuProvider: AppIntentTimelineProvider {
    /// Check back at least this often, in case the dining hall edits the menu.
    private static let maximumAge: TimeInterval = 6 * 60 * 60
    private static let retryInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> MenuEntry {
        .sample(design: .makeDefault(.menu))
    }

    func snapshot(for configuration: MenuWidgetIntent, in context: Context) async -> MenuEntry {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .menu)
        if context.isPreview {
            return .sample(design: design)
        }
        return await timeline(for: configuration, in: context).entries.first ?? .sample(design: design)
    }

    func timeline(for configuration: MenuWidgetIntent, in context: Context) async -> Timeline<MenuEntry> {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .menu)
        let selection = design.menuConfiguration?.meal ?? .lunch
        let now = Date.now
        do {
            // MenuService falls back to its cached copy when offline, so this throws only when
            // there's nothing to show at all.
            let upcoming = try await MenuService().upcomingMenu(for: selection, now: now)
            let refresh = max(
                min(upcoming.validUntil, now.addingTimeInterval(Self.maximumAge)),
                now.addingTimeInterval(5 * 60)
            )
            let entries = Self.entryDates(from: now, until: refresh).map {
                MenuEntry(date: $0, design: design, upcoming: upcoming)
            }
            return Timeline(entries: entries, policy: .after(refresh))
        } catch {
            let entry = MenuEntry(date: now, design: design, upcoming: nil)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.retryInterval)))
        }
    }

    /// `now`, plus each midnight (school time) before `end`, so "Tomorrow" becomes "Today" on time.
    private static func entryDates(from now: Date, until end: Date) -> [Date] {
        var dates = [now]
        var day = LocalDate(now).adding(days: 1)
        while day.startOfDay() < end {
            dates.append(day.startOfDay())
            day = day.adding(days: 1)
        }
        return dates
    }
}

#Preview(as: .systemMedium) {
    MenuWidget()
} timeline: {
    MenuEntry.sample(design: .makeDefault(.menu))
}
