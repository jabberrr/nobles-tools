import Foundation

/// Field formats shared by the Nobles athletics results feed and schedule page.
enum AthleticsParsing {
    /// Team levels as they end a team name, longest first so "JV A" wins over "JV".
    static let levels = ["Middle School", "JV A", "JV B", "JV", "3rd", "Varsity", "Junior", "MS"]

    /// Splits a team name of the form "<Sport> [Boys|Girls] <Level>" into a sport, gender first,
    /// and a level: "Volleyball Girls JV A" → ("Girls Volleyball", "JV A"),
    /// "Cross Country Middle School" → ("Cross Country", "Middle School"), "Pickleball" → ("Pickleball", nil).
    static func team(_ name: String) -> (sport: String, level: String?) {
        var words = name.collapsingWhitespace.split(separator: " ").map(String.init)
        var level: String?
        for candidate in levels {
            let levelWords = candidate.matchKey.split(separator: " ").map(String.init)
            if words.count > levelWords.count, words.suffix(levelWords.count).map(\.matchKey) == levelWords {
                words.removeLast(levelWords.count)
                level = candidate
                break
            }
        }
        if words.count > 1, let gender = words.last, ["boys", "girls"].contains(gender.matchKey) {
            words.insert(words.removeLast(), at: 0)
        }
        return (words.joined(separator: " "), level)
    }

    /// The opponent as shown, or "" when the source lists none ("None" or blank).
    static func opponent(_ text: String?) -> String {
        let opponent = text?.collapsingWhitespace ?? ""
        return opponent.matchKey == "none" ? "" : opponent
    }

    /// A month-day-year date such as "10/19/2026" or "10.26.26"; two-digit years are 20xx.
    static func date(_ text: String, separator: Character) -> LocalDate? {
        let parts = text.trimmed.split(separator: separator).map { Int($0) }
        guard parts.count == 3, let month = parts[0], let day = parts[1], var year = parts[2] else { return nil }
        if year < 100 { year += 2000 }
        guard DateComponents(calendar: .school, year: year, month: month, day: day).isValidDate else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }

    /// A clock time such as "4:00 PM" or "10:30am"; `nil` for "TBA" or anything else.
    static func time(_ text: String) -> (hour: Int, minute: Int)? {
        let compact = text.lowercased().filter { !$0.isWhitespace && $0 != "." }
        let isPM = compact.hasSuffix("pm")
        guard isPM || compact.hasSuffix("am") else { return nil }
        let clock = compact.dropLast(2).split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(clock.count),
              let hour = Int(clock[0]), (1...12).contains(hour),
              let minute = clock.count == 2 ? Int(clock[1]) : 0, (0...59).contains(minute)
        else { return nil }
        return (hour % 12 + (isPM ? 12 : 0), minute)
    }

    /// A result such as "W 3-1", "Win 76-24" or "L": the outcome, plus points in the order
    /// written (Nobles first, as the site writes them) when there are two numbers.
    static func score(fromResult text: String) -> GameScore? {
        let key = text.matchKey
        guard let outcome = GameScore.Outcome(word: String(key.prefix(while: \.isLetter))) else { return nil }
        let points = key.split { !$0.isNumber }.compactMap { Int($0) }
        guard points.count >= 2 else { return GameScore(outcome: outcome) }
        return GameScore(outcome: outcome, nobles: points[0], opponent: points[1])
    }
}

extension GameScore.Outcome {
    /// "W"/"Win"/"Won", "L"/"Loss"/"Lost" or "T"/"Tie"/"Tied", ignoring case.
    init?(word: String) {
        switch word.matchKey {
        case "w", "win", "won": self = .win
        case "l", "loss", "lost": self = .loss
        case "t", "tie", "tied": self = .tie
        default: return nil
        }
    }
}
