import Foundation

/// Shorter forms of a game's names, for tight spaces.
extension Game {
    /// The opponent as schools are called in conversation: without a leading "The", trailing
    /// "School", "Academy" or "Preparatory", or anything after a comma.
    /// "The Rivers School" → "Rivers", "Austin Preparatory School" → "Austin",
    /// "St. Paul's School, NH" → "St. Paul's". The whole name when that would leave nothing.
    public var shortOpponent: String {
        let name = opponent.split(separator: ",", maxSplits: 1).first ?? ""
        var words = name.split(separator: " ").map(String.init)
        if words.first?.matchKey == "the" {
            words.removeFirst()
        }
        while let last = words.last, Self.institutionWords.contains(last.matchKey) {
            words.removeLast()
        }
        return words.isEmpty ? opponent : words.joined(separator: " ")
    }

    /// The initials of a `shortOpponent` of three or more words, as such schools are often known:
    /// "Buckingham Browne & Nichols" → "BB&N", "Cambridge School of Weston" → "CSW". `nil` for
    /// shorter names.
    public var opponentInitials: String? {
        let words = shortOpponent.split(separator: " ")
        guard words.count >= 3 else { return nil }
        return words.compactMap { word -> String? in
            if word == "&" { return "&" }
            guard !Self.minorWords.contains(word.lowercased()) else { return nil }
            return word.first.map { String($0).uppercased() }
        }
        .joined()
    }

    /// The team's level, abbreviated where it's long ("MS" for "Middle School"); `nil` for varsity
    /// teams, whose level goes unsaid, and when it's unknown.
    public var shortLevel: String? {
        guard let level, !level.isEmpty, level.matchKey != "varsity" else { return nil }
        return level.matchKey == "middle school" ? "MS" : level
    }

    private static let institutionWords: Set<String> = ["school", "academy", "preparatory", "prep"]
    private static let minorWords: Set<String> = ["of", "the", "and"]
}
