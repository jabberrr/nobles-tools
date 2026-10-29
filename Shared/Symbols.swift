import Foundation
import NoblesKit

/// Picks an SF Symbol for a free-text name, such as a sport or a menu station, by the first
/// keyword the name contains, ignoring case and accents. More specific keywords go first.
struct KeywordSymbols: Sendable {
    let table: [(keyword: String, symbol: String)]
    let fallback: String

    func symbol(for name: String) -> String {
        let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return table.first { key.contains($0.keyword) }?.symbol ?? fallback
    }
}

/// SF Symbols for Nobles sports, matched loosely against names like "Girls Field Hockey".
enum SportSymbol {
    static func name(for sport: String) -> String {
        symbols.symbol(for: sport)
    }

    private static let symbols = KeywordSymbols(
        table: [
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
        ],
        fallback: "sportscourt"
    )
}

/// SF Symbols for dining-hall stations, matched loosely against titles such as "Vegan Entree" or
/// "Dracula's Cookie Extravaganza". Kinds of food come before kinds of course, so "Vegan Entree"
/// gets the leaf rather than the pan.
enum StationSymbol {
    static func name(for station: String) -> String {
        symbols.symbol(for: station)
    }

    private static let symbols = KeywordSymbols(
        table: [
            ("vegan", "leaf"),
            ("vegetarian", "leaf"),
            ("plant", "leaf"),
            ("soup", "mug"),
            ("chowder", "mug"),
            ("salad", "carrot"),
            ("dessert", "birthday.cake"),
            ("cookie", "birthday.cake"),
            ("cake", "birthday.cake"),
            ("bake", "birthday.cake"),
            ("sweet", "birthday.cake"),
            ("pizza", "flame"),
            ("grill", "flame"),
            ("bbq", "flame"),
            ("deli", "takeoutbag.and.cup.and.straw"),
            ("sandwich", "takeoutbag.and.cup.and.straw"),
            ("breakfast", "sunrise"),
            ("fish", "fish"),
            ("seafood", "fish"),
            ("drink", "cup.and.saucer"),
            ("beverage", "cup.and.saucer"),
            ("side", "basket"),
            ("entree", "frying.pan"),
            ("main", "frying.pan"),
            ("option", "frying.pan"),
        ],
        fallback: "fork.knife"
    )
}

/// SF Symbols for school breaks, by name: "Thanksgiving Break" gets a leaf, "Winter Break" a
/// snowflake.
enum BreakSymbol {
    static func name(for schoolBreak: SchoolBreak) -> String {
        symbols.symbol(for: schoolBreak.name)
    }

    private static let symbols = KeywordSymbols(
        table: [
            ("thanksgiving", "leaf"),
            ("winter", "snowflake"),
            ("holiday", "snowflake"),
            ("march", "sun.max"),
            ("spring", "sun.max"),
            ("day", "flag"),
        ],
        fallback: "beach.umbrella"
    )
}
