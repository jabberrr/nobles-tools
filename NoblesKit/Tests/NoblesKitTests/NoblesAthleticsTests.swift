import Foundation
import Testing
@testable import NoblesKit

struct NoblesAthleticsTests {
    private func results() throws -> [Game] {
        try AthleticsResult.games(from: Fixture.data("real-athletics-results.json"))
    }

    private func schedule() throws -> [Game] {
        try AthleticsSchedule.games(from: Fixture.data("real-athletics-schedule.html"))
    }

    // MARK: Results feed

    @Test func decodesRealResults() throws {
        let games = try results()

        #expect(games.count == 100)
        #expect(games.allSatisfy { $0.status == .final && !$0.hasStartTime })
        let outcomes = Dictionary(grouping: games) { $0.score?.outcome.rawValue ?? "none" }.mapValues(\.count)
        #expect(outcomes == ["W": 58, "L": 31, "T": 11])
    }

    @Test func trustsTheReportedOutcome() throws {
        let race = try #require(try results().first { $0.opponent == "Tabor Academy" && $0.sport == "Boys Cross Country" })

        #expect(race.id == "result-94671")
        #expect(race.level == "Varsity")
        #expect(race.start == LocalDate(2026, 10, 17).at(hour: 12))
        #expect(race.score == GameScore(outcome: .loss, nobles: 15, opponent: 59))
    }

    @Test func outcomeWithoutAScoreHasNoPoints() throws {
        let games = try results()
        let fenn = try #require(games.first { $0.opponent == "The Fenn School" })

        #expect(fenn.sport == "Boys Soccer")
        #expect(fenn.level == "Middle School")
        #expect(fenn.score == GameScore(outcome: .win))
        #expect(fenn.score?.scoreline == nil)
        #expect(games.first { $0.id == "result-97192" }?.opponent == "")
    }

    @Test func skipsUnusableResultRows() throws {
        let json = #"""
        [{"event_id": 1, "team_name": "Squash Boys Varsity", "athletic_opponent": "Milton", "game_score_us": 4,
          "game_score_opponent": 3, "formatted_start_date": "1/9/2027", "outcome": "w", "score": "4-3"},
         {"event_id": "2", "team_name": "Squash Boys Varsity", "formatted_start_date": "1/9/2027", "outcome": "X"},
         {"event_id": "3", "team_name": "Squash Boys Varsity", "formatted_start_date": "13/40/2027", "outcome": "W"},
         {"event_id": "4", "formatted_start_date": "1/9/2027", "outcome": "W"},
         "unexpected"]
        """#
        let games = try AthleticsResult.games(from: Data(json.utf8))

        #expect(games.map(\.id) == ["result-1"])
        #expect(games.first?.score == GameScore(outcome: .win, nobles: 4, opponent: 3))
        #expect(throws: ScoresServiceError.unrecognizedResponse) {
            try AthleticsResult.games(from: Data(#"{"error": "down"}"#.utf8))
        }
    }

    // MARK: Schedule page

    @Test func decodesRealSchedule() throws {
        let games = try schedule()

        #expect(games.count == 30)
        #expect(Set(games.map { LocalDate($0.start) }) == Set((0..<6).map { LocalDate(2026, 10, 26).adding(days: $0) }))
        #expect(games.filter { LocalDate($0.start) == LocalDate(2026, 10, 28) }.count == 12)
        #expect(games.allSatisfy { $0.status == .scheduled && $0.hasStartTime })

        #expect(games.first == Game(
            id: "sched-Field Hockey Girls Middle School|Dana Hall School|2026-10-26|4:00 PM",
            sport: "Girls Field Hockey",
            level: "Middle School",
            opponent: "Dana Hall School",
            isHome: false,
            start: LocalDate(2026, 10, 26).at(hour: 16),
            location: "Dana Hall School",
            status: .scheduled
        ))
    }

    @Test func decodesEntitiesInTheSchedule() throws {
        let games = try schedule()
        let soccer = try #require(games.first { $0.sport == "Boys Soccer" && $0.level == "Varsity" })

        #expect(soccer.opponent == "Governor's Academy")
        #expect(soccer.location == "Nobles-'49/Greene Field")
        #expect(soccer.isHome == true)
        #expect(games.contains { $0.opponent == "Buckingham Browne & Nichols School" })
        #expect(games.contains { $0.sport == "Pickleball" && $0.level == nil && $0.opponent == "" })
    }

    @Test func readsOnlyGameRowsInTheSidebar() throws {
        let html = """
        <div class="ath-row" data-date="11.01.26" data-type="Game" data-team="Outside Before"></div>
        <aside class="home-sidebar">
        <div class="ath-rowline"><div class="ath-key">Date</div></div>
        <div class="ath-row ath-click is-practice" data-date="11.02.26" data-type="Practice" data-team="Soccer Boys Varsity"></div>
        <DIV class="ath-row" data-date="11.03.26" data-team="Hockey Boys  JV" data-opponent="St. Sebastian&#x2019;s"
            data-start="TBA" data-map="10 Campus Drive
        Dedham, MA" data-result="W 3-1"></DIV>
        <div class="ath-row ath-click" data-date="11.04.26" data-type="Game" data-team="Squash Girls Varsity"
            data-start="3:30 PM" data-result="See recap"></div>
        <div class="ath-row" data-team="No Date"></div>
        </aside>
        <div class="ath-row" data-date="11.05.26" data-type="Game" data-team="Outside After"></div>
        """
        let games = try AthleticsSchedule.games(from: Data(html.utf8))

        #expect(games.map(\.sport) == ["Boys Hockey", "Girls Squash"])
        let hockey = games[0]
        #expect(hockey.opponent == "St. Sebastian\u{2019}s")
        #expect(hockey.start == LocalDate(2026, 11, 3).at(hour: 12))
        #expect(!hockey.hasStartTime)
        #expect(hockey.status == .final)
        #expect(hockey.score == GameScore(outcome: .win, nobles: 3, opponent: 1))
        #expect(games[1].status == .scheduled)
        #expect(games[1].start == LocalDate(2026, 11, 4).at(hour: 15, minute: 30))

        #expect(throws: ScoresServiceError.unrecognizedResponse) {
            try AthleticsSchedule.games(from: Data("<html><body>Maintenance</body></html>".utf8))
        }
    }

    @Test func emptySidebarMeansNoGames() throws {
        let html = """
        <html><body><main>Go Bulldogs!</main>
        <aside class="home-sidebar">
          <h3 class="section-title">Upcoming Schedule</h3>
          <div class="ath-schedule"></div>
        </aside>
        </body></html>
        """
        #expect(try AthleticsSchedule.games(from: Data(html.utf8)).isEmpty)
    }

    @Test func decodesHTMLEntities() {
        #expect("Governor&#039;s &amp; St. Mark&#x2019;s &lt;b&gt;&quot;&apos;".decodingHTMLEntities == "Governor's & St. Mark\u{2019}s <b>\"'")
        #expect("AT&T &bogus; & 5 &#;".decodingHTMLEntities == "AT&T &bogus; & 5 &#;")
    }

    // MARK: Field formats

    @Test(arguments: [
        ("Volleyball Girls Varsity", "Girls Volleyball", "Varsity"),
        ("Volleyball Girls JV A", "Girls Volleyball", "JV A"),
        ("Volleyball Girls JV B", "Girls Volleyball", "JV B"),
        ("Soccer Boys JV", "Boys Soccer", "JV"),
        ("Soccer Boys 3rd", "Boys Soccer", "3rd"),
        ("Football Boys Junior", "Boys Football", "Junior"),
        ("Field Hockey Girls Middle School", "Girls Field Hockey", "Middle School"),
        ("Cross Country Middle School", "Cross Country", "Middle School"),
        ("Cross Country Boys Varsity", "Boys Cross Country", "Varsity"),
        ("  Squash   Boys  ms ", "Boys Squash", "MS"),
        ("Pickleball", "Pickleball", nil),
        ("Varsity", "Varsity", nil),
    ] as [(String, String, String?)])
    func splitsTeamNames(team: String, sport: String, level: String?) {
        let parsed = AthleticsParsing.team(team)
        #expect(parsed.sport == sport)
        #expect(parsed.level == level)
    }

    @Test(arguments: [
        ("W 3-1", GameScore(outcome: .win, nobles: 3, opponent: 1)),
        ("Win 76-24", GameScore(outcome: .win, nobles: 76, opponent: 24)),
        ("L 0 - 3", GameScore(outcome: .loss, nobles: 0, opponent: 3)),
        ("loss", GameScore(outcome: .loss)),
        ("T 2-2", GameScore(outcome: .tie, nobles: 2, opponent: 2)),
        ("Postponed", nil),
        ("", nil),
    ] as [(String, GameScore?)])
    func parsesResultText(text: String, score: GameScore?) {
        #expect(AthleticsParsing.score(fromResult: text) == score)
    }

    @Test func parsesClockTimes() {
        func minutes(_ text: String) -> Int? {
            AthleticsParsing.time(text).map { $0.hour * 60 + $0.minute }
        }
        #expect(minutes("4:00 PM") == 16 * 60)
        #expect(minutes("12:00 PM") == 12 * 60)
        #expect(minutes("12:15 AM") == 15)
        #expect(minutes("9:30am") == 9 * 60 + 30)
        #expect(minutes("TBA") == nil)
        #expect(minutes("13:00 PM") == nil)
    }

    // MARK: Provider

    private func http(results: FakeHTTPClient.Response, schedule: FakeHTTPClient.Response) -> FakeHTTPClient {
        FakeHTTPClient([NoblesAthleticsProvider.resultsURL: results, NoblesAthleticsProvider.scheduleURL: schedule])
    }

    private let season = (start: LocalDate(2026, 9, 1).startOfDay(), end: LocalDate(2026, 12, 1).startOfDay())
    private let now = LocalDate(2026, 10, 25).at(hour: 9)

    private func onlineSources() throws -> FakeHTTPClient {
        http(results: .data(try Fixture.data("real-athletics-results.json")), schedule: .data(try Fixture.data("real-athletics-schedule.html")))
    }

    @Test func mergesBothSourcesWithinTheWindow() async throws {
        let provider = NoblesAthleticsProvider(http: try onlineSources(), cache: nil)

        #expect(provider.sourceName == "Nobles Athletics")
        #expect(try await provider.games(from: season.start, to: season.end, now: now).games.count == 130)
        let lastWeek = try await provider.games(from: LocalDate(2026, 10, 17).startOfDay(), to: LocalDate(2026, 10, 27).startOfDay(), now: now)
        #expect(lastWeek.games.count == 10)
    }

    @Test func resultsReplaceTheirScheduledGames() {
        let day = LocalDate(2026, 10, 7)
        func scheduled(_ opponent: String, level: String? = "Varsity", daysLater: Int = 0) -> Game {
            Game(id: "sched-\(opponent)-\(level ?? "")-\(daysLater)", sport: "Boys Soccer", level: level, opponent: opponent,
                 start: day.adding(days: daysLater).at(hour: 15, minute: 30), status: .scheduled)
        }
        let results = [
            Game(id: "result-1", sport: "Boys Soccer", level: "Varsity", opponent: "Tabor", start: day.at(hour: 12),
                 hasStartTime: false, status: .final, score: GameScore(outcome: .win, nobles: 4, opponent: 0)),
            Game(id: "result-2", sport: "Boys Soccer", level: "Varsity", opponent: "St. Mark\u{2019}s School", start: day.at(hour: 12),
                 hasStartTime: false, status: .final, score: GameScore(outcome: .win)),
            Game(id: "result-3", sport: "Boys Soccer", level: "Varsity", opponent: "", start: day.at(hour: 12),
                 hasStartTime: false, status: .final, score: GameScore(outcome: .tie)),
        ]
        let schedule = [
            scheduled("Tabor Academy"),
            scheduled("st. mark's school"),
            scheduled(""),
            scheduled("Tabor Academy", level: "JV"),
            scheduled("Tabor Academy", daysLater: 1),
            scheduled("Milton Academy"),
        ]
        let merged = NoblesAthleticsProvider.merged(results: results, schedule: schedule)

        #expect(merged.map(\.id) == ["result-1", "result-2", "result-3"] + schedule.suffix(3).map(\.id))
    }

    @Test func oneFailingSourceStillReturnsTheOther() async throws {
        let provider = NoblesAthleticsProvider(
            http: http(results: .failure(HTTPError.status(500)), schedule: .data(try Fixture.data("real-athletics-schedule.html"))),
            cache: nil
        )
        let feed = try await provider.games(from: season.start, to: season.end, now: now)

        #expect(feed.games.count == 30)
        #expect(feed.fetchedAt == now)
    }

    @Test func throwsWhenBothSourcesFail() async {
        let provider = NoblesAthleticsProvider(
            http: http(results: .failure(HTTPError.status(500)), schedule: .data(Data("<html>Maintenance</html>".utf8))),
            cache: nil
        )
        await #expect(throws: HTTPError.status(500)) {
            try await provider.games(from: season.start, to: season.end, now: now)
        }
    }

    @Test func fallsBackToCachedSources() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let fresh = try await NoblesAthleticsProvider(http: try onlineSources(), cache: cache).games(from: season.start, to: season.end, now: now)
        #expect(fresh.fetchedAt == now)

        let offline = NoblesAthleticsProvider(http: http(results: .failure(Offline()), schedule: .failure(Offline())), cache: cache)
        #expect(try await offline.games(from: season.start, to: season.end, now: now).games == fresh.games)
    }

    @Test func feedIsAsOldAsItsOldestCachedSource() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let (hourAgo, dayAgo) = (Date.now - 60 * 60, Date.now - 24 * 60 * 60)
        await cache.store(try Fixture.data("real-athletics-results.json"), for: NoblesAthleticsProvider.resultsURL.absoluteString, savedAt: hourAgo)
        await cache.store(try Fixture.data("real-athletics-schedule.html"), for: NoblesAthleticsProvider.scheduleURL.absoluteString, savedAt: dayAgo)
        func fetchedAt(schedule: FakeHTTPClient.Response) async throws -> Date {
            let provider = NoblesAthleticsProvider(http: http(results: .failure(Offline()), schedule: schedule), cache: cache)
            return try await provider.games(from: season.start, to: season.end, now: now).fetchedAt
        }

        // Both sources from the cache, then only the results (the schedule loads fresh).
        #expect(abs(try await fetchedAt(schedule: .failure(Offline())).timeIntervalSince(dayAgo)) < 1)
        #expect(abs(try await fetchedAt(schedule: .data(try Fixture.data("real-athletics-schedule.html"))).timeIntervalSince(hourAgo)) < 1)
    }

    @Test func scoreboardReportsWhenCachedGamesWereFetched() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let savedAt = Date.now - 3 * 60 * 60
        await cache.store(try Fixture.data("real-athletics-results.json"), for: NoblesAthleticsProvider.resultsURL.absoluteString, savedAt: savedAt)
        let provider = NoblesAthleticsProvider(http: http(results: .failure(Offline()), schedule: .failure(Offline())), cache: cache)

        let now = LocalDate(2026, 10, 21).at(hour: 9)
        let service = ScoresService(provider: provider)
        let board = try await service.scoreboard(for: ScoresConfiguration(), now: now)
        #expect(board.recent.first?.opponent == "Concord Academy")
        #expect(abs(board.fetchedAt.timeIntervalSince(savedAt)) < 1)
        #expect(try await service.feed(now: now).fetchedAt == board.fetchedAt)
    }
}
