import Foundation
import NoblesKit

extension Game {
    /// "Boys Soccer · JV": the level is left out for varsity teams.
    var teamText: String {
        guard let level, !level.isEmpty, level.caseInsensitiveCompare("Varsity") != .orderedSame else { return sport }
        return "\(sport) · \(level)"
    }

    /// "vs Thayer Academy", "at Tabor Academy", or empty for a meet with no single opponent.
    var matchupText: String {
        guard !opponent.isEmpty else { return "" }
        return "\(isHome == false ? "at" : "vs") \(opponent)"
    }

    /// Where the game is played, e.g. "Nobles-Burr Field"; `nil` when that's unknown or just the
    /// opponent's name, as it is for most away games.
    var venueText: String? {
        guard let location, !location.isEmpty,
              opponent.isEmpty || !location.localizedCaseInsensitiveContains(opponent)
        else { return nil }
        return location
    }

    /// "Oct 19", or "Today" / "Yesterday" for recent games.
    func dateText(today: LocalDate) -> String {
        let day = LocalDate(start)
        return abs(today.days(until: day)) <= 1 ? SchoolFormat.relativeDay(day, from: today) : SchoolFormat.shortDate(day)
    }

    /// "Wed 4:00 PM", "Today 4:00 PM", or just the day when no time is known.
    func whenText(today: LocalDate) -> String {
        let day = LocalDate(start)
        let dayText = today.days(until: day) <= 1 ? SchoolFormat.relativeDay(day, from: today) : SchoolFormat.weekday(day)
        return hasStartTime ? "\(dayText) \(SchoolFormat.time(start))" : dayText
    }

    /// Stands in for a score when there isn't one, e.g. "Awaiting result" or "Postponed".
    func statusText(now: Date) -> String {
        switch status {
        case .live(let detail): ["Live", detail].compactMap { $0 }.joined(separator: " · ")
        case .postponed: "Postponed"
        case .cancelled: "Cancelled"
        case .final: "Final"
        case .scheduled: start <= now ? "Awaiting result" : whenText(today: LocalDate(now))
        }
    }
}

extension GameScore.Outcome {
    /// "Win", "Loss" or "Tie".
    var word: String {
        switch self {
        case .win: "Win"
        case .loss: "Loss"
        case .tie: "Tie"
        }
    }
}

extension ScoresConfiguration {
    /// What the design is filtered to, e.g. "Varsity · Boys Soccer, Girls Soccer".
    var summaryText: String {
        let level = varsityOnly ? "Varsity" : "All levels"
        let teams = sports.isEmpty ? "All sports" : sports.joined(separator: ", ")
        return "\(level) · \(teams)"
    }
}

/// SF Symbols for Nobles sports, matched loosely against names like "Girls Field Hockey".
enum SportSymbol {
    private static let table: [(keyword: String, symbol: String)] = [
        ("field hockey", "figure.hockey"),
        ("hockey", "hockey.puck"),
        ("soccer", "soccerball"),
        ("football", "football"),
        ("basketball", "basketball"),
        ("volleyball", "volleyball"),
        ("baseball", "baseball"),
        ("softball", "baseball"),
        ("lacrosse", "figure.lacrosse"),
        ("tennis", "tennis.racket"),
        ("pickleball", "tennis.racket"),
        ("squash", "figure.squash"),
        ("cross country", "figure.run"),
        ("track", "figure.run"),
        ("swim", "figure.pool.swim"),
        ("diving", "figure.pool.swim"),
        ("ski", "figure.skiing.downhill"),
        ("wrestling", "figure.wrestling"),
        ("golf", "figure.golf"),
        ("crew", "figure.rower"),
        ("rowing", "figure.rower"),
        ("sailing", "sailboat"),
        ("fencing", "figure.fencing"),
    ]

    static func name(for sport: String) -> String {
        let key = sport.lowercased()
        return table.first { key.contains($0.keyword) }?.symbol ?? "sportscourt"
    }
}
