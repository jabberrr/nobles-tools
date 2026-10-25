import SwiftUI
import WidgetKit
import NoblesKit

struct ScoresWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ScoresWidget", intent: ScoresWidgetIntent.self, provider: ScoresProvider()) { entry in
            WidgetChrome(design: entry.design) { family in
                ScoresWidgetView(design: entry.design, family: family, scoreboard: entry.scoreboard, now: entry.date)
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

struct ScoresProvider: AppIntentTimelineProvider {
    private static let refreshInterval: TimeInterval = 30 * 60
    /// Used around game time, when a result may be posted.
    private static let gameTimeRefreshInterval: TimeInterval = 15 * 60
    private static let gameTimeWindow: TimeInterval = 3 * 60 * 60

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

    func timeline(for configuration: ScoresWidgetIntent, in context: Context) async -> Timeline<ScoresEntry> {
        let design = DesignStore().resolvedDesign(id: configuration.design?.id, kind: .scores)
        let now = Date.now
        do {
            // ScoresService falls back to its cached copy (with an older `fetchedAt`) when the
            // feed is down, so this throws only when there's nothing to show at all.
            let scoreboard = try await ScoresService.nobles.scoreboard(
                for: design.scoresConfiguration ?? ScoresConfiguration(),
                now: now
            )
            let entry = ScoresEntry(date: now, design: design, scoreboard: scoreboard)
            let interval = Self.isNearGameTime(scoreboard, now: now) ? Self.gameTimeRefreshInterval : Self.refreshInterval
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(interval)))
        } catch {
            let entry = ScoresEntry(date: now, design: design, scoreboard: nil)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.refreshInterval)))
        }
    }

    /// Whether a game is in progress, or one without a result starts (or started) within a few hours.
    private static func isNearGameTime(_ scoreboard: Scoreboard, now: Date) -> Bool {
        !scoreboard.live.isEmpty || (scoreboard.upcoming + scoreboard.recent).contains { game in
            game.score == nil && abs(game.start.timeIntervalSince(now)) < gameTimeWindow
        }
    }
}

#Preview(as: .systemMedium) {
    ScoresWidget()
} timeline: {
    ScoresEntry.sample(design: .makeDefault(.scores))
}
