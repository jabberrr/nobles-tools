import SwiftUI
import WidgetKit
import NoblesKit

struct ScoresWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKind.scores.timelineKind,
            intent: ScoresWidgetIntent.self,
            provider: ScoresTimelineProvider()
        ) { entry in
            WidgetChrome(design: entry.design) { family, colors in
                ScoresWidgetView(design: entry.design, family: family, colors: colors, scoreboard: entry.scoreboard, now: entry.date)
            }
        }
        .configurationDisplayName(WidgetKind.scores.displayName)
        .description(WidgetKind.scores.summary)
        .supportedFamilies(WidgetKind.scores.widgetFamilies)
    }
}

struct ScoresEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    /// `nil` when nothing could be loaded, even from the cache.
    let scoreboard: Scoreboard?

    static func sample(design: WidgetDesign, date: Date = .now) -> ScoresEntry {
        ScoresEntry(date: date, design: design, scoreboard: .sample)
    }
}

struct ScoresTimelineProvider: AppIntentTimelineProvider {
    /// Results are posted days after each game, so a couple of hours is fresh enough.
    private static let refreshInterval: TimeInterval = 2 * 60 * 60
    /// On a day with a game, in case its result is posted the same day.
    private static let gameDayRefreshInterval: TimeInterval = 60 * 60
    private static let retryInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> ScoresEntry {
        .sample(design: .makeDefault(.scores))
    }

    func snapshot(for configuration: ScoresWidgetIntent, in context: Context) async -> ScoresEntry {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .scores)
        if context.isPreview {
            return .sample(design: design)
        }
        return await timeline(for: configuration, in: context).entries.first ?? .sample(design: design)
    }

    /// The scoreboard now, and again at midnight (school time) so dates and the split between
    /// results and upcoming games stay right overnight.
    func timeline(for configuration: ScoresWidgetIntent, in context: Context) async -> Timeline<ScoresEntry> {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .scores)
        let filters = design.scoresConfiguration ?? ScoresConfiguration()
        let now = Date.now
        // ScoresService falls back to its cached copy (with an older `fetchedAt`) when the feed is
        // down, so this fails only when there's nothing to show at all.
        guard let feed = try? await ScoresService.nobles.feed(now: now) else {
            let entry = ScoresEntry(date: now, design: design, scoreboard: nil)
            return Timeline(entries: [entry], policy: .after(now + Self.retryInterval))
        }
        let scoreboard = Scoreboard(feed: feed, configuration: filters, now: now)
        let midnight = LocalDate(now).adding(days: 1).startOfDay()
        let entries = [
            ScoresEntry(date: now, design: design, scoreboard: scoreboard),
            ScoresEntry(date: midnight, design: design, scoreboard: Scoreboard(feed: feed, configuration: filters, now: midnight)),
        ]
        let interval = Self.hasGameToday(scoreboard, now: now) ? Self.gameDayRefreshInterval : Self.refreshInterval
        return Timeline(entries: entries, policy: .after(now + interval))
    }

    /// Whether a game shown is on today and has no result yet: in progress, still to come, or
    /// played and awaiting its score.
    private static func hasGameToday(_ scoreboard: Scoreboard, now: Date) -> Bool {
        let today = LocalDate(now)
        return !scoreboard.live.isEmpty || (scoreboard.upcoming + scoreboard.recent).contains { game in
            game.status == .scheduled && LocalDate(game.start) == today
        }
    }
}

#Preview(as: .systemMedium) {
    ScoresWidget()
} timeline: {
    ScoresEntry.sample(design: .makeDefault(.scores))
}
