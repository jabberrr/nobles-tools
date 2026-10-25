import Foundation
import Testing
@testable import NoblesKit

struct ScoreboardTests {
    private let today = LocalDate(2026, 10, 28)
    private var now: Date { today.at(hour: 16) }

    private func game(
        _ id: String,
        sport: String = "Boys Soccer",
        level: String? = "Varsity",
        day offset: Int,
        hour: Int? = 15,
        _ status: GameStatus
    ) -> Game {
        let day = today.adding(days: offset)
        return Game(
            id: id, sport: sport, level: level, opponent: "Milton Academy",
            start: day.at(hour: hour ?? 12), hasStartTime: hour != nil, status: status
        )
    }

    @Test func sortsGamesByStatusAndTime() {
        let games = [
            game("final-yesterday", day: -1, .final),
            game("final-today", day: 0, hour: nil, .final),
            game("awaiting-today", day: 0, hour: 15, .scheduled),
            game("awaiting-old", day: -2, .scheduled),
            game("tba-today", day: 0, hour: nil, .scheduled),
            game("tonight", day: 0, hour: 18, .scheduled),
            game("tomorrow", day: 1, .scheduled),
            game("live", day: 0, hour: 15, .live(detail: "2nd half")),
            game("cancelled", day: -1, hour: 10, .cancelled),
            game("postponed-tomorrow", day: 1, .postponed),
        ]
        let board = Scoreboard(games: games, configuration: ScoresConfiguration(varsityOnly: false), now: now)

        #expect(board.live.map(\.id) == ["live"])
        #expect(board.recent.map(\.id) == ["awaiting-today", "final-today", "final-yesterday", "cancelled", "awaiting-old"])
        #expect(board.upcoming.map(\.id) == ["tba-today", "tonight", "tomorrow"])
        #expect(board.fetchedAt == now)
        #expect(!board.isEmpty)
    }

    @Test func varsityOnlyKeepsVarsityAndUnknownLevels() {
        let games = [
            game("varsity", level: "Varsity", day: -1, .final),
            game("unknown", sport: "Pickleball", level: nil, day: -1, .final),
            game("jv", level: "JV A", day: -1, .final),
            game("middle-school", level: "Middle School", day: -1, .final),
        ]
        let varsity = Scoreboard(games: games, configuration: ScoresConfiguration(varsityOnly: true), now: now)
        let everyone = Scoreboard(games: games, configuration: ScoresConfiguration(varsityOnly: false), now: now)

        #expect(Set(varsity.recent.map(\.id)) == ["varsity", "unknown"])
        #expect(everyone.recent.count == 4)
    }

    @Test func filtersBySportExactlyIgnoringCase() {
        let games = [
            game("boys", sport: "Boys Soccer", day: -1, .final),
            game("girls", sport: "Girls Soccer", day: -1, .final),
            game("ms-xc", sport: "Cross Country", level: "Middle School", day: -1, .final),
            game("boys-xc", sport: "Boys Cross Country", day: -1, .final),
        ]
        func shown(_ sports: [String]) -> Set<String> {
            let configuration = ScoresConfiguration(sports: sports, varsityOnly: false)
            return Set(Scoreboard(games: games, configuration: configuration, now: now).recent.map(\.id))
        }

        #expect(shown(["boys soccer", " "]) == ["boys"])
        #expect(shown(["Cross Country"]) == ["ms-xc"])
        #expect(shown(["GIRLS SOCCER", "Boys Cross Country"]) == ["girls", "boys-xc"])
        #expect(shown(["Soccer"]).isEmpty)
        #expect(shown([]).count == 4)
    }

    @Test func feedListsEachSportOnceInOrder() {
        let feed = GameFeed(games: [
            game("volleyball", sport: "Girls Volleyball", day: -1, .final),
            game("soccer-next", sport: "Boys Soccer", day: 1, .scheduled),
            game("xc", sport: "Cross Country", day: -2, .final),
            game("soccer-last", sport: "Boys Soccer", day: -3, .final),
        ], fetchedAt: now)

        #expect(feed.sports == ["Boys Soccer", "Cross Country", "Girls Volleyball"])
        #expect(GameFeed(games: [], fetchedAt: now).sports.isEmpty)
    }

    @Test func scoreboardFromAFeedKeepsItsFetchTime() {
        let fetchedAt = now - 2 * 60 * 60
        let feed = GameFeed(games: [game("final", day: -1, .final)], fetchedAt: fetchedAt)
        let board = Scoreboard(feed: feed, configuration: ScoresConfiguration(), now: now)

        #expect(board.recent.map(\.id) == ["final"])
        #expect(board.fetchedAt == fetchedAt)
        #expect(Scoreboard(games: feed.games, configuration: ScoresConfiguration(), now: now, fetchedAt: fetchedAt) == board)
    }

    @Test func canHideUpcomingGames() {
        let games = [game("final", day: -1, .final), game("tomorrow", day: 1, .scheduled)]
        let board = Scoreboard(games: games, configuration: ScoresConfiguration(showsUpcoming: false), now: now)

        #expect(board.recent.map(\.id) == ["final"])
        #expect(board.upcoming.isEmpty)
        #expect(Scoreboard(games: [], configuration: ScoresConfiguration(), now: now).isEmpty)
    }

    @Test func sampleLooksLikeTheRealSource() {
        let sample = Scoreboard.sample
        #expect(sample.live.isEmpty)
        #expect(!sample.recent.isEmpty)
        #expect(!sample.upcoming.isEmpty)
    }

    @Test func serviceAsksForAMonthBackAndTwoWeeksAhead() async throws {
        let provider = RecordingProvider()
        let service = ScoresService(provider: provider)
        let board = try await service.scoreboard(for: ScoresConfiguration(), now: now)

        #expect(service.sourceName == "Recording")
        #expect(board.isEmpty)
        #expect(board.fetchedAt == now - 60 * 60)
        let request = try #require(await provider.request)
        #expect(request.start == now - 30 * 24 * 60 * 60)
        #expect(request.end == now + 14 * 24 * 60 * 60)
        #expect(request.now == now)
    }
}

/// Records what it was asked for and answers with no games, fetched an hour before `now`.
private actor RecordingProvider: ScoresProvider {
    nonisolated let sourceName = "Recording"
    private(set) var request: (start: Date, end: Date, now: Date)?

    func games(from start: Date, to end: Date, now: Date) async throws -> GameFeed {
        request = (start, end, now)
        return GameFeed(games: [], fetchedAt: now - 60 * 60)
    }
}
