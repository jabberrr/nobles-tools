import Foundation

/// One Nobles athletic contest, scheduled, in progress or final.
public struct Game: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    /// e.g. "Football", "Girls Soccer"
    public var sport: String
    /// e.g. "Varsity", "JV"; `nil` when the source doesn't say.
    public var level: String?
    public var opponent: String
    /// `nil` when the source doesn't say (or the game is at a neutral site).
    public var isHome: Bool?
    public var start: Date
    /// Whether `start` carries a real time of day rather than just a date.
    public var hasStartTime: Bool
    public var location: String?
    public var status: GameStatus
    public var score: GameScore?

    public init(
        id: String,
        sport: String,
        level: String? = nil,
        opponent: String,
        isHome: Bool? = nil,
        start: Date,
        hasStartTime: Bool = true,
        location: String? = nil,
        status: GameStatus,
        score: GameScore? = nil
    ) {
        self.id = id
        self.sport = sport
        self.level = level
        self.opponent = opponent
        self.isHome = isHome
        self.start = start
        self.hasStartTime = hasStartTime
        self.location = location
        self.status = status
        self.score = score
    }
}

/// Where a game stands. The Nobles source only reports `.scheduled` and `.final`; `.live`,
/// `.postponed` and `.cancelled` are kept so a future live source fits.
public enum GameStatus: Codable, Hashable, Sendable {
    case scheduled
    /// In progress; `detail` is e.g. "Q3" or "2nd half" when the source provides it.
    case live(detail: String?)
    case final
    case postponed
    case cancelled
}

/// Games from a provider, and when they were fetched.
public struct GameFeed: Hashable, Sendable {
    public var games: [Game]
    /// When the data was fetched: now for a fresh response, or when a cached copy was saved.
    public var fetchedAt: Date

    public init(games: [Game], fetchedAt: Date) {
        self.games = games
        self.fetchedAt = fetchedAt
    }

    /// Distinct `Game.sport` values, sorted, for pickers.
    public var sports: [String] {
        Set(games.map(\.sport)).sorted()
    }
}

/// A final result as Nobles Athletics reports it.
public struct GameScore: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case win = "W"
        case loss = "L"
        case tie = "T"
    }

    /// Taken from the source rather than computed: in sports like cross country the
    /// lower score wins.
    public var outcome: Outcome
    /// Points for each side; `nil` when only the outcome was posted (common for
    /// middle school games and meets).
    public var nobles: Int?
    public var opponent: Int?

    public init(outcome: Outcome, nobles: Int? = nil, opponent: Int? = nil) {
        self.outcome = outcome
        self.nobles = nobles
        self.opponent = opponent
    }

    /// "3–0" (Nobles first), or `nil` when no score was posted.
    public var scoreline: String? {
        guard let nobles, let opponent else { return nil }
        return "\(nobles)–\(opponent)"
    }
}

public struct ScoresConfiguration: Codable, Hashable, Sendable {
    /// Sports to include, each equal to a `Game.sport` ignoring case (see `GameFeed.sports`).
    /// Empty means all.
    public var sports: [String]
    public var varsityOnly: Bool
    public var showsUpcoming: Bool

    public init(sports: [String] = [], varsityOnly: Bool = true, showsUpcoming: Bool = true) {
        self.sports = sports
        self.varsityOnly = varsityOnly
        self.showsUpcoming = showsUpcoming
    }

    /// Missing fields take their defaults, so settings saved by other versions still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ScoresConfiguration()
        sports = try container.decode(.sports, or: defaults.sports)
        varsityOnly = try container.decode(.varsityOnly, or: defaults.varsityOnly)
        showsUpcoming = try container.decode(.showsUpcoming, or: defaults.showsUpcoming)
    }
}
