import Foundation

public enum ScoresServiceError: Error, Equatable {
    /// A source answered with something other than results or a schedule, e.g. a redesigned page.
    case unrecognizedResponse
}

/// Games from the Nobles athletics site: the latest results (JSON, about a week behind) and the
/// home page's upcoming schedule (HTML, about six days ahead). There are no live scores. Each
/// source falls back to its cached copy on failure, so widgets keep working offline.
public struct NoblesAthleticsProvider: ScoresProvider {
    /// The 100 most recent results, newest first.
    public static let resultsURL = URL(string: "https://nobilis.nobles.edu/Athletics/endpoints/latest_results.php?page=1")!
    /// The athletics home page, whose sidebar lists upcoming games.
    public static let scheduleURL = URL(string: "https://nobilis.nobles.edu/Athletics/")!

    public let sourceName = "Nobles Athletics"
    private let fetcher: CachingFetcher

    public init(http: any HTTPClient = URLSessionHTTPClient(), cache: ResponseCache? = .shared) {
        fetcher = CachingFetcher(http: http, cache: cache)
    }

    /// Results and scheduled games starting from `start` through `end`. A scheduled game that
    /// already has a result appears once, as the result. Throws only if neither source loads.
    public func games(from start: Date, to end: Date) async throws -> [Game] {
        try await fetchGames(from: start, to: end).games
    }

    /// `games(from:to:)`, with the older save date of any source served from the cache.
    public func fetchGames(from start: Date, to end: Date) async throws -> (games: [Game], cachedAt: Date?) {
        async let loadingResults = load(Self.resultsURL, parse: AthleticsResult.games)
        async let loadingSchedule = load(Self.scheduleURL, parse: AthleticsSchedule.games)
        let (results, schedule) = await (loadingResults, loadingSchedule)
        let loaded = [results, schedule].compactMap { try? $0.get() }
        if loaded.isEmpty, case .failure(let error) = results {
            throw error
        }
        let games = Self.merged(results: (try? results.get().value) ?? [], schedule: (try? schedule.get().value) ?? [])
        return (games.filter { start <= $0.start && $0.start <= end }, loaded.compactMap(\.cachedAt).min())
    }

    private func load(_ url: URL, parse: @Sendable (Data) throws -> [Game]) async -> Result<CachingFetcher.Fetched<[Game]>, any Error> {
        do {
            return .success(try await fetcher.fetch(url, decode: parse))
        } catch {
            return .failure(error)
        }
    }

    /// The results plus the scheduled games they don't cover. A result covers a scheduled game on
    /// the same day for the same sport and level against the same opponent, where names match
    /// ignoring case, apostrophe style and one containing the other ("Tabor" / "Tabor Academy").
    static func merged(results: [Game], schedule: [Game]) -> [Game] {
        results + schedule.filter { scheduled in !results.contains { $0.isSameGame(as: scheduled) } }
    }
}

private extension Game {
    func isSameGame(as other: Game) -> Bool {
        guard LocalDate(start) == LocalDate(other.start),
              sport.matchKey == other.sport.matchKey,
              level?.matchKey == other.level?.matchKey
        else { return false }
        let (mine, theirs) = (opponentKey, other.opponentKey)
        guard !mine.isEmpty, !theirs.isEmpty else { return mine == theirs }
        return mine.contains(theirs) || theirs.contains(mine)
    }

    var opponentKey: String {
        opponent.matchKey.replacingOccurrences(of: "\u{2019}", with: "'")
    }
}
