import Foundation

extension Game {
    /// The opponent as schools are called in conversation, for tight spaces: without a leading
    /// "The", trailing "School", "Academy" or "Preparatory", or anything after a comma.
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

    private static let institutionWords: Set<String> = ["school", "academy", "preparatory", "prep"]
}
