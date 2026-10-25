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

public enum GameStatus: Codable, Hashable, Sendable {
    case scheduled
    /// In progress; `detail` is e.g. "Q3" or "2nd half" when the source provides it.
    case live(detail: String?)
    case final
    case postponed
    case cancelled
}

public struct GameScore: Codable, Hashable, Sendable {
    public var nobles: Int
    public var opponent: Int

    public init(nobles: Int, opponent: Int) {
        self.nobles = nobles
        self.opponent = opponent
    }

    public enum Outcome: String, Sendable {
        case win = "W"
        case loss = "L"
        case tie = "T"
    }

    public var outcome: Outcome {
        nobles > opponent ? .win : nobles < opponent ? .loss : .tie
    }
}

public struct ScoresConfiguration: Codable, Hashable, Sendable {
    /// Sports to include, matched case-insensitively against `Game.sport`. Empty means all.
    public var sports: [String]
    public var varsityOnly: Bool
    public var showsUpcoming: Bool

    public init(sports: [String] = [], varsityOnly: Bool = true, showsUpcoming: Bool = true) {
        self.sports = sports
        self.varsityOnly = varsityOnly
        self.showsUpcoming = showsUpcoming
    }
}
