import Foundation

/// One row of `latest_results.php`, e.g. `{"event_id": "97207", "team_name": "Volleyball Girls
/// Varsity", "athletic_opponent": "Concord Academy", "game_score_us": "3", "game_score_opponent":
/// "0", "formatted_start_date": "10/19/2026", "outcome": "W", "score": "3-0"}`. Every field is
/// optional and numbers may arrive as strings or null.
struct AthleticsResult: Decodable {
    var eventID: String?
    var team: String?
    var opponent: String?
    var date: String?
    var outcome: String?
    var score: String?
    var pointsUs: Int?
    var pointsThem: Int?

    private enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case team = "team_name"
        case opponent = "athletic_opponent"
        case date = "formatted_start_date"
        case outcome, score
        case pointsUs = "game_score_us"
        case pointsThem = "game_score_opponent"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = container.text(forKey: .eventID) ?? container.integer(forKey: .eventID).map(String.init)
        team = container.text(forKey: .team)
        opponent = container.text(forKey: .opponent)
        date = container.text(forKey: .date)
        outcome = container.text(forKey: .outcome)
        score = container.text(forKey: .score)
        pointsUs = container.integer(forKey: .pointsUs)
        pointsThem = container.integer(forKey: .pointsThem)
    }

    /// Every row that has a team, a date and a W/L/T outcome, as final games. The feed has no
    /// times, so games are placed at noon with `hasStartTime == false`.
    static func games(from data: Data) throws -> [Game] {
        guard let rows = try? JSONDecoder().decode([Lossy<AthleticsResult>].self, from: data) else {
            throw ScoresServiceError.unrecognizedResponse
        }
        return rows.compactMap { $0.value?.game }
    }

    /// Points count only when both parse and `score` isn't blank: middle school rows report
    /// `"0"`/null with an empty score when only the outcome was posted.
    var game: Game? {
        guard let team,
              let day = date.flatMap({ AthleticsParsing.date($0, separator: "/") }),
              let outcome = outcome.flatMap(GameScore.Outcome.init(word:))
        else { return nil }
        let (sport, level) = AthleticsParsing.team(team)
        let opponent = AthleticsParsing.opponent(opponent)
        let hasPoints = score != nil && pointsUs != nil && pointsThem != nil
        return Game(
            id: "result-" + (eventID ?? "\(team)|\(opponent)|\(day.iso)"),
            sport: sport,
            level: level,
            opponent: opponent,
            start: day.at(hour: 12),
            hasStartTime: false,
            status: .final,
            score: GameScore(outcome: outcome, nobles: hasPoints ? pointsUs : nil, opponent: hasPoints ? pointsThem : nil)
        )
    }
}
