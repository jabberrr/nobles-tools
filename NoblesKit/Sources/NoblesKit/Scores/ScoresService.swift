import Foundation

/// A source of Nobles game results and schedules.
public protocol ScoresProvider: Sendable {
    /// Shown in the app, e.g. "Nobles Athletics".
    var sourceName: String { get }
    /// Games starting between `start` and `end`. A fresh feed is stamped `now`; one served from
    /// an offline cache is stamped when that copy was saved.
    func games(from start: Date, to end: Date, now: Date) async throws -> GameFeed
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

    /// Games from 30 days before `now` to 14 days after.
    public func feed(now: Date = .now) async throws -> GameFeed {
        try await provider.games(from: now - Self.lookBack, to: now + Self.lookAhead, now: now)
    }

    /// `feed(now:)`, filtered and sorted for `configuration`.
    public func scoreboard(for configuration: ScoresConfiguration, now: Date = .now) async throws -> Scoreboard {
        Scoreboard(feed: try await feed(now: now), configuration: configuration, now: now)
    }
}
