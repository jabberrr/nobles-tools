import Foundation

extension MenuItem {
    /// The dish without its trimmings, for tight spaces: the last ", …" part, or else a
    /// " with …" ending, is dropped as long as two words are left.
    /// "Black Widow Soup, Sour Cream & Scallions" → "Black Widow Soup",
    /// "Roasted Green Beans with Shallots" → "Roasted Green Beans". Otherwise the whole name.
    public var shortName: String {
        let candidates = [
            name.range(of: ",", options: .backwards),
            name.range(of: " with ", options: .caseInsensitive),
        ]
        for case let range? in candidates {
            let head = String(name[..<range.lowerBound]).trimmed
            if head.split(separator: " ").count >= 2 {
                return head
            }
        }
        return name
    }
}
