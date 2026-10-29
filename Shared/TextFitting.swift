import SwiftUI

/// Draws the first of `variants` (longest first) that fits, using `content`. When none fits, the
/// last is drawn anyway, so end with the shortest. Up to six variants are tried.
///
/// Keep variants in one list rather than nesting this in another `ViewThatFits`: an outer one
/// measures only an inner one's first child.
struct FirstFitting<Variant, Content: View>: View {
    let variants: [Variant]
    var axes: Axis.Set = [.horizontal, .vertical]
    @ViewBuilder let content: (Variant) -> Content

    var body: some View {
        if !variants.isEmpty {
            ViewThatFits(in: axes) {
                content(variant(0))
                content(variant(1))
                content(variant(2))
                content(variant(3))
                content(variant(4))
                content(variant(5))
            }
        }
    }

    private func variant(_ index: Int) -> Variant {
        variants[min(index, variants.count - 1)]
    }
}

extension String {
    /// The text cut short at word boundaries, longest first, each ending in "…", for when even its
    /// short form won't fit: "Revved Up Macaroni…", "Revved Up…". A cut never ends on a word like
    /// "&" or "with", or on punctuation, and keeps at least one word.
    func cutsAtWords(limit: Int) -> [String] {
        var words = split(separator: " ").map(String.init)
        var cuts: [String] = []
        while cuts.count < limit, words.count > 1 {
            words.removeLast()
            while let last = words.last, Self.danglingWords.contains(last.lowercased()) {
                words.removeLast()
            }
            guard !words.isEmpty else { break }
            var cut = words.joined(separator: " ")
            while let last = cut.last, ",;:-–".contains(last) {
                cut.removeLast()
            }
            cuts.append(cut + "…")
        }
        return cuts
    }

    private static let danglingWords: Set<String> = ["&", "and", "with", "of", "de", "in", "on", "the", "a", "vs", "at", "-", "–"]
}
