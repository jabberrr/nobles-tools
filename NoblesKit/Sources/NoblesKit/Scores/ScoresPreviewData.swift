import Foundation

extension Scoreboard {
    /// A realistic scoreboard built from real October 2026 Nobles games, dated around now, for
    /// previews and placeholders. Like the real source it has no live games.
    public static var sample: Scoreboard { sample(now: .now) }

    /// The sample scoreboard with games dated around `now`, for renders that must not change
    /// from day to day.
    public static func sample(now: Date) -> Scoreboard {
        let today = LocalDate(now)
        func day(_ offset: Int, at hour: Int = 12, _ minute: Int = 0) -> Date {
            today.adding(days: offset).at(hour: hour, minute: minute)
        }
        let games = [
            Game(id: "sample-1", sport: "Girls Volleyball", level: "Varsity", opponent: "Concord Academy",
                 start: day(-1), hasStartTime: false, status: .final, score: GameScore(outcome: .win, nobles: 3, opponent: 0)),
            Game(id: "sample-2", sport: "Girls Field Hockey", level: "Varsity", opponent: "Dexter Southfield",
                 start: day(-1), hasStartTime: false, status: .final, score: GameScore(outcome: .win, nobles: 2, opponent: 1)),
            Game(id: "sample-3", sport: "Boys Football", level: "Varsity", opponent: "The Rivers School",
                 start: day(-3), hasStartTime: false, status: .final, score: GameScore(outcome: .win, nobles: 35, opponent: 20)),
            Game(id: "sample-4", sport: "Boys Soccer", level: "Varsity", opponent: "Thayer Academy",
                 start: day(-3), hasStartTime: false, status: .final, score: GameScore(outcome: .loss, nobles: 0, opponent: 3)),
            Game(id: "sample-5", sport: "Boys Cross Country", level: "Varsity", opponent: "Tabor Academy",
                 start: day(-3), hasStartTime: false, status: .final, score: GameScore(outcome: .loss, nobles: 15, opponent: 59)),
            Game(id: "sample-6", sport: "Boys Soccer", level: "Varsity", opponent: "Governor's Academy", isHome: true,
                 start: day(1, at: 15, 15), location: "Nobles-'49/Greene Field", status: .scheduled),
            Game(id: "sample-7", sport: "Girls Volleyball", level: "Varsity", opponent: "Austin Preparatory School", isHome: false,
                 start: day(2, at: 17), location: "Austin Preparatory School", status: .scheduled),
            Game(id: "sample-8", sport: "Boys Football", level: "Varsity", opponent: "Lawrence Academy", isHome: true,
                 start: day(4, at: 14), location: "Nobles-Burr Field", status: .scheduled),
        ]
        return Scoreboard(games: games, configuration: ScoresConfiguration(), now: now)
    }
}
