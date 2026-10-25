import Foundation

/// Games sorted into what a scores widget shows, after a design's filters.
public struct Scoreboard: Hashable, Sendable {
    /// In progress, soonest start first. The Nobles source has no live scores, so this is always
    /// empty for now; it's kept so a future live source fits.
    public var live: [Game]
    /// Finished, postponed or cancelled games, plus scheduled games that should have started but
    /// have no result yet ("Awaiting result"); newest first.
    public var recent: [Game]
    /// Scheduled games that haven't started, soonest first. Empty when the design hides them.
    public var upcoming: [Game]
    /// When the games were fetched (see `GameFeed.fetchedAt`).
    public var fetchedAt: Date

    public var isEmpty: Bool { live.isEmpty && recent.isEmpty && upcoming.isEmpty }

    /// Applies `configuration`'s sport and varsity filters to `games` and sorts them by status.
    /// `fetchedAt` defaults to `now`.
    public init(games: [Game], configuration: ScoresConfiguration, now: Date, fetchedAt: Date? = nil) {
        let today = LocalDate(now)
        let shown = games.filter(configuration.includes)
        live = shown.filter(\.isLive).sorted(by: Game.startsEarlier)
        recent = shown.filter { $0.isRecent(now: now, today: today) }.sorted { Game.startsEarlier($1, $0) }
        upcoming = configuration.showsUpcoming
            ? shown.filter { $0.status == .scheduled && !$0.hasStarted(now: now) }.sorted(by: Game.startsEarlier)
            : []
        self.fetchedAt = fetchedAt ?? now
    }

    /// The scoreboard for `feed`'s games, fetched when the feed was.
    public init(feed: GameFeed, configuration: ScoresConfiguration, now: Date) {
        self.init(games: feed.games, configuration: configuration, now: now, fetchedAt: feed.fetchedAt)
    }
}

extension ScoresConfiguration {
    /// Whether `game` passes the sport and varsity filters. A sport matches when it equals a chosen
    /// name ignoring case, so "Cross Country" (middle school) doesn't pick up "Boys Cross Country".
    /// Varsity-only keeps games whose level is "Varsity" or unknown.
    func includes(_ game: Game) -> Bool {
        let chosen = sports.map(\.matchKey).filter { !$0.isEmpty }
        let sportMatches = chosen.isEmpty || chosen.contains(game.sport.matchKey)
        let levelMatches = !varsityOnly || game.level.map { $0.matchKey == "varsity" } ?? true
        return sportMatches && levelMatches
    }
}

extension Game {
    /// Whether the game should have begun: its start time has passed or, for a game with only a
    /// date, its day is over.
    func hasStarted(now: Date) -> Bool {
        hasStartTime ? start <= now : LocalDate(start) < LocalDate(now)
    }

    fileprivate var isLive: Bool {
        if case .live = status { true } else { false }
    }

    fileprivate func isRecent(now: Date, today: LocalDate) -> Bool {
        switch status {
        case .final, .postponed, .cancelled: LocalDate(start) <= today
        case .scheduled: hasStarted(now: now)
        case .live: false
        }
    }

    /// Start time, then ID so equal starts sort the same way every time.
    fileprivate static func startsEarlier(_ lhs: Game, _ rhs: Game) -> Bool {
        (lhs.start, lhs.id) < (rhs.start, rhs.id)
    }
}
