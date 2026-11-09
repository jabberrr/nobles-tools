import SwiftUI
import WidgetKit
import NoblesKit

struct StoreWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.spending.timelineKind,
            intent: StoreWidgetIntent.self,
            provider: StoreTimelineProvider()
        ) { entry in
            WidgetChrome(design: entry.design) { family, colors in
                StoreWidgetView(design: entry.design, family: family, colors: colors, statement: entry.statement, status: entry.status, now: entry.date)
            }
        }
        .configurationDisplayName(WidgetKind.spending.displayName)
        .description(WidgetKind.spending.summary)
        .supportedFamilies(WidgetKind.spending.widgetFamilies)
    }
}

struct StoreEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    /// `nil` when there's nothing to show, even from the cache.
    let statement: StoreStatement?
    /// How current and connected `statement` is.
    let status: StoreStatus

    static func sample(design: WidgetDesign, date: Date = .now) -> StoreEntry {
        StoreEntry(date: date, design: design, statement: .sample, status: .live)
    }
}

struct StoreTimelineProvider: AppIntentTimelineProvider {
    /// Charges post quickly, but spending changes slowly, so a couple of hours is fresh enough.
    private static let refreshInterval: TimeInterval = 2 * 60 * 60
    private static let retryInterval: TimeInterval = 30 * 60
    /// With no account connected, there's nothing to fetch, so don't check back often.
    private static let disconnectedInterval: TimeInterval = 4 * 60 * 60

    func placeholder(in context: Context) -> StoreEntry {
        .sample(design: .makeDefault(.spending))
    }

    func snapshot(for configuration: StoreWidgetIntent, in context: Context) async -> StoreEntry {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .spending)
        if context.isPreview {
            return .sample(design: design)
        }
        return await timeline(for: configuration, in: context).entries.first ?? .sample(design: design)
    }

    /// The spending now and again at the next school midnight, so the charges' "Today" and
    /// "Yesterday" labels stay right overnight. Falls back to a cached copy when the sign-in has
    /// lapsed or the network is down, and prompts a re-connect in the app when it can't refresh.
    func timeline(for configuration: StoreWidgetIntent, in context: Context) async -> Timeline<StoreEntry> {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .spending)
        let now = Date.now
        guard let session = StoreSessionStore().load() else {
            let entry = StoreEntry(date: now, design: design, statement: nil, status: .disconnected)
            return Timeline(entries: [entry], policy: .after(now + Self.disconnectedInterval))
        }

        let statement: StoreStatement?
        let status: StoreStatus
        let interval: TimeInterval
        do {
            statement = try await StoreService.nobles.statement(for: session, now: now)
            status = .live
            interval = Self.refreshInterval
        } catch StoreError.notAuthenticated {
            statement = await StoreService.nobles.cachedStatement()
            status = .signedOut
            interval = Self.refreshInterval
        } catch {
            statement = await StoreService.nobles.cachedStatement()
            status = .offline
            interval = Self.retryInterval
        }

        let midnight = LocalDate(now).adding(days: 1).startOfDay()
        let entries = [
            StoreEntry(date: now, design: design, statement: statement, status: status),
            StoreEntry(date: midnight, design: design, statement: statement, status: status),
        ]
        return Timeline(entries: entries, policy: .after(now + interval))
    }
}

#Preview(as: .systemMedium) {
    StoreWidget()
} timeline: {
    StoreEntry.sample(design: .makeDefault(.spending))
}
