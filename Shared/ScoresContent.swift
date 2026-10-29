import Foundation
import NoblesKit

/// What a scores design shows, worked out once from its settings and scoreboard for every size.
///
/// Nobles Athletics posts final results only, about a week behind, so nothing here says "live"
/// unless a game's status really is `.live`.
struct ScoresContent {
    /// Whether anything could be loaded, if only a cached copy.
    let isAvailable: Bool
    /// Games in progress, then results (and games awaiting one), newest first.
    let results: [Game]
    /// Upcoming games, soonest first; empty when the design hides them.
    let upcoming: [Game]
    /// "Updated 3h ago" when the scoreboard is an older cached copy.
    let staleness: String?
    /// What the design is filtered to, e.g. "Varsity · Girls Soccer", for when nothing matches.
    let filterSummary: String
    /// The moment on screen (the timeline entry's date).
    let now: Date

    init(scoreboard: Scoreboard?, configuration: ScoresConfiguration, now: Date) {
        isAvailable = scoreboard != nil
        results = scoreboard.map { $0.live + $0.recent } ?? []
        upcoming = configuration.showsUpcoming ? scoreboard?.upcoming ?? [] : []
        staleness = scoreboard.flatMap { Self.staleness(of: $0, now: now) }
        filterSummary = configuration.summaryText
        self.now = now
    }

    var today: LocalDate { LocalDate(now) }

    /// The game to show where only one fits: the latest result, else the next game.
    var featured: Game? { results.first ?? upcoming.first }

    /// "Updated 3h ago" when the scoreboard is an older cached copy. The threshold sits above the
    /// widget's 2-hour refresh, so data that is merely between refreshes isn't flagged.
    private static func staleness(of scoreboard: Scoreboard, now: Date) -> String? {
        guard now.timeIntervalSince(scoreboard.fetchedAt) > 3 * 60 * 60,
              let age = SchoolFormat.age(of: scoreboard.fetchedAt, now: now)
        else { return nil }
        return "Updated \(age)"
    }
}
