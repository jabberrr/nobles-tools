import SwiftUI
import WidgetKit
import NoblesKit

struct MenuWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.menu.timelineKind,
            intent: MenuWidgetIntent.self,
            provider: MenuTimelineProvider()
        ) { entry in
            WidgetChrome(design: entry.design) { family, colors in
                MenuWidgetView(design: entry.design, family: family, colors: colors, upcoming: entry.upcoming, now: entry.date)
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

struct MenuTimelineProvider: AppIntentTimelineProvider {
    /// Check back at least this often, in case the dining hall edits the menu.
    private static let maximumAge: TimeInterval = 6 * 60 * 60
    /// Never reload sooner than this, so a menu that has only just ended can't cause a reload loop.
    private static let minimumAge: TimeInterval = 5 * 60
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

    /// The menu now, and the one that replaces it when its meal ends, so the widget moves on at
    /// the right time even if WidgetKit is late to reload.
    func timeline(for configuration: MenuWidgetIntent, in context: Context) async -> Timeline<MenuEntry> {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .menu)
        let selection = design.menuConfiguration?.meal ?? .lunch
        let now = Date.now
        // MenuService falls back to its cached copy when offline, so this fails only when there's
        // nothing to show at all.
        guard let menus = try? await MenuService().upcomingMenus(for: selection, now: now, limit: 2),
              let current = menus.first
        else {
            let entry = MenuEntry(date: now, design: design, upcoming: nil)
            return Timeline(entries: [entry], policy: .after(now + Self.retryInterval))
        }
        let refresh = min(max(current.validUntil, now + Self.minimumAge), now + Self.maximumAge)
        return Timeline(entries: Self.entries(for: menus, design: design, now: now), policy: .after(refresh))
    }

    /// An entry now, one as each menu takes over from the one before, and one at each midnight
    /// (school time) until the last menu ends, so "Tomorrow" becomes "Today" on time. Each shows
    /// the menu that's current at its date.
    private static func entries(for menus: [UpcomingMenu], design: WidgetDesign, now: Date) -> [MenuEntry] {
        guard let last = menus.last else { return [] }
        var dates: Set<Date> = [now]
        dates.formUnion(menus.dropLast().map(\.validUntil))
        var day = LocalDate(now).adding(days: 1)
        while day.startOfDay() < last.validUntil {
            dates.insert(day.startOfDay())
            day = day.adding(days: 1)
        }
        return dates.sorted().map { date in
            MenuEntry(date: date, design: design, upcoming: menus.first { date < $0.validUntil } ?? last)
        }
    }
}

#Preview(as: .systemMedium) {
    MenuWidget()
} timeline: {
    MenuEntry.sample(design: .makeDefault(.menu))
}
