import Foundation

/// The "Upcoming Schedule" on the Nobles athletics home page. Each game is a
/// `<div class="ath-row …">` whose `data-*` attributes carry its details: `data-date`
/// ("10.26.26"), `data-type` ("Game"), `data-team`, `data-opponent`, `data-homeaway`, `data-loc`,
/// `data-start` ("4:00 PM") and `data-result` (empty until played).
enum AthleticsSchedule {
    /// A page without the schedule's markup is an error rather than "no games", so it never
    /// replaces a good cached copy.
    static func games(from data: Data) throws -> [Game] {
        let html = String(decoding: data, as: UTF8.self)
        guard html.contains("ath-row") else { throw ScoresServiceError.unrecognizedResponse }
        return HTMLScanning.startTags(named: "div", in: html)
            .filter { ($0["class"] ?? "").split(separator: " ").contains("ath-row") }
            .compactMap(game(fromRow:))
    }

    /// A game from one row's attributes; `nil` for non-game rows (such as practices) or rows
    /// without a team or date. A row without a usable start time is placed at noon.
    static func game(fromRow row: [String: String]) -> Game? {
        guard row["data-type"].map({ $0.matchKey == "game" }) ?? true,
              let team = row["data-team"]?.collapsingWhitespace.nonEmpty,
              let day = row["data-date"].flatMap({ AthleticsParsing.date($0, separator: ".") })
        else { return nil }
        let (sport, level) = AthleticsParsing.team(team)
        let opponent = AthleticsParsing.opponent(row["data-opponent"])
        let startText = row["data-start"]?.trimmed ?? ""
        let time = AthleticsParsing.time(startText)
        let score = row["data-result"].flatMap(AthleticsParsing.score(fromResult:))
        return Game(
            id: "sched-\(team)|\(opponent)|\(day.iso)|\(startText)",
            sport: sport,
            level: level,
            opponent: opponent,
            isHome: row["data-homeaway"].flatMap(isHome),
            start: time.map { day.at(hour: $0.hour, minute: $0.minute) } ?? day.at(hour: 12),
            hasStartTime: time != nil,
            location: row["data-loc"]?.collapsingWhitespace.nonEmpty,
            status: score == nil ? .scheduled : .final,
            score: score
        )
    }

    private static func isHome(_ text: String) -> Bool? {
        switch text.matchKey {
        case "home": true
        case "away": false
        default: nil
        }
    }
}
