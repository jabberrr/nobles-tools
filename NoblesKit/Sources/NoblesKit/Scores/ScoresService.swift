import Foundation

/// A source of Nobles game results and schedules.
public protocol ScoresProvider: Sendable {
    /// Shown in the app, e.g. "Nobles Athletics".
    var sourceName: String { get }
    /// Games starting between `start` and `end`.
    func games(from start: Date, to end: Date) async throws -> [Game]
    /// `games(from:to:)` plus, when any of them came from an offline cache, when that copy was
    /// fetched; `nil` means fresh. The default implementation always reports fresh games.
    func fetchGames(from start: Date, to end: Date) async throws -> (games: [Game], cachedAt: Date?)
}

extension ScoresProvider {
    public func fetchGames(from start: Date, to end: Date) async throws -> (games: [Game], cachedAt: Date?) {
        (try await games(from: start, to: end), nil)
    }
}

/// Builds scoreboards for scores widgets from a provider.
public struct ScoresService: Sendable {
    /// Results are posted about a week late, so look back well past that.
    static let lookBack: TimeInterval = 30 * 24 * 60 * 60
    static let lookAhead: TimeInterval = 14 * 24 * 60 * 60

    private let provider: any ScoresProvider

    public init(provider: any ScoresProvider) {
        self.provider = provider
    }

    /// Results and schedules from the Nobles athletics site.
    public static let nobles = ScoresService(provider: NoblesAthleticsProvider())

    public var sourceName: String { provider.sourceName }

    /// Games from 30 days before `now` to 14 days after, filtered and sorted for `configuration`.
    /// When the provider served cached games, `fetchedAt` is when that copy was fetched.
    public func scoreboard(for configuration: ScoresConfiguration, now: Date = .now) async throws -> Scoreboard {
        let fetched = try await provider.fetchGames(from: now - Self.lookBack, to: now + Self.lookAhead)
        var scoreboard = Scoreboard(games: fetched.games, configuration: configuration, now: now)
        scoreboard.fetchedAt = fetched.cachedAt ?? now
        return scoreboard
    }
}
