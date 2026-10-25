import Foundation

extension String {
    /// Without leading or trailing whitespace and newlines.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `nil` when empty.
    var nonEmpty: String? { isEmpty ? nil : self }

    /// Runs of whitespace collapsed to single spaces, trimmed.
    var collapsingWhitespace: String { split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    /// Lowercased, accent-free and trimmed, for loose matching: "Entrée " → "entree".
    var matchKey: String {
        trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Whether `matchKey` contains any of `keywords`, which must already be match keys.
    func containsAny(of keywords: [String]) -> Bool {
        let key = matchKey
        return keywords.contains { key.contains($0) }
    }
}
