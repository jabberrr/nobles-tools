import Foundation

extension DailyMenu {
    /// The menu narrowed to what `filter` asks for. Station titles and dish names match ignoring
    /// case and accents ("Entrée" == "entree"). Notes are always kept; empty sections are dropped.
    ///
    /// Nobles' categories are always empty, so the built-in filters go by station title first:
    /// - `.entreesOnly`: stations named "…Entree…" or "…Main…", or ending in "Option" (dinner's
    ///   "Vegan Option"), plus entrée-category dishes from other stations. Without any entrées the
    ///   menu is empty.
    /// - `.withoutSaladsAndSoups`: drops soup and salad stations, and dishes whose category or name
    ///   says soup, salad, chowder, bisque or gazpacho.
    /// - `.only` / `.excluding`: a station is selected when its title and a chosen name contain one
    ///   another. An empty choice means everything.
    public func filtered(by filter: MenuFilter) -> DailyMenu {
        var menu = self
        menu.sections = filteredSections(filter).filter { !$0.items.isEmpty }
        return menu
    }

    private func filteredSections(_ filter: MenuFilter) -> [MenuSection] {
        switch filter {
        case .everything:
            return sections
        case .entreesOnly:
            return sections.map { $0.isEntreeStation ? $0 : $0.keeping(\.isEntree) }
        case .withoutSaladsAndSoups:
            return sections
                .filter { !$0.title.containsAny(of: MenuKeywords.soupOrSaladStation) }
                .map { $0.keeping { !$0.isSoupOrSalad } }
        case .only(let names):
            let names = MenuKeywords.selection(names)
            return names.isEmpty ? sections : sections.filter { $0.isSelected(by: names) }
        case .excluding(let names):
            let names = MenuKeywords.selection(names)
            return sections.filter { !$0.isSelected(by: names) }
        }
    }

    /// The dishes to feature when space is tight: entrées first, by the same rules as
    /// `.entreesOnly` (dishes in entrée stations, then entrée-category dishes elsewhere), then
    /// every other dish, each group in menu order. A dish listed twice appears once.
    public var highlights: [MenuItem] {
        let otherDishes = sections.filter { !$0.isEntreeStation }.flatMap(\.items)
        let ordered = sections.filter(\.isEntreeStation).flatMap(\.items)
            + otherDishes.filter(\.isEntree)
            + otherDishes.filter { !$0.isEntree }
        var seen: Set<Int> = []
        return ordered.filter { seen.insert($0.id).inserted }
    }

    /// The first dish of the station `station` names, or `nil` when no such station is serving.
    /// Titles match loosely, the way "Just…" matches them, and failing that by their distinctive
    /// words, so "Vegan Entree" also finds dinner's "Vegan Option".
    public func firstDish(atStation station: String) -> MenuItem? {
        let names = MenuKeywords.selection([station])
        guard !names.isEmpty else { return nil }
        let serving = sections.filter { !$0.items.isEmpty }
        let words = station.distinctiveWords
        let match = serving.first { $0.isSelected(by: names) }
            ?? serving.first { !words.isDisjoint(with: $0.title.distinctiveWords) }
        return match?.items.first
    }
}

extension MenuConfiguration {
    /// The dish this design features: the only one on Lock Screen widgets, and the first on Home
    /// Screen ones.
    ///
    /// A chosen station is looked up on the whole menu, so choosing one overrides the filter. When
    /// it isn't serving, or none is chosen, the first highlight of the filtered menu stands in.
    public func featuredDish(in menu: DailyMenu) -> MenuItem? {
        featuredStation.flatMap(menu.firstDish(atStation:)) ?? menu.filtered(by: filter).highlights.first
    }
}

private enum MenuKeywords {
    static let entreeStation = ["entree", "main"]
    static let soupOrSaladStation = ["soup", "salad"]
    static let soupOrSaladDish = ["soup", "salad", "chowder", "bisque", "gazpacho"]

    /// Words that say what kind of station a title is rather than what it serves.
    static let genericStationWords: Set<String> = [
        "entree", "entrees", "option", "options", "station", "hot", "weekly", "composed", "daily",
        "bar", "special", "specials", "main", "the", "of", "and", "&",
    ]

    /// The user's chosen station names as match keys, without blanks.
    static func selection(_ names: [String]) -> [String] {
        names.map(\.matchKey).filter { !$0.isEmpty }
    }
}

private extension String {
    /// The words of a station title that say what it serves: "Vegan Entree" → ["vegan"].
    var distinctiveWords: Set<String> {
        Set(matchKey.split(separator: " ").map(String.init)).subtracting(MenuKeywords.genericStationWords)
    }
}

private extension MenuSection {
    var isEntreeStation: Bool {
        title.containsAny(of: MenuKeywords.entreeStation) || title.matchKey.hasSuffix("option")
    }

    /// Whether this titled section matches one of `names` (match keys) in either direction.
    func isSelected(by names: [String]) -> Bool {
        let title = title.matchKey
        return !title.isEmpty && names.contains { title.contains($0) || $0.contains(title) }
    }

    func keeping(_ isIncluded: (MenuItem) -> Bool) -> MenuSection {
        MenuSection(title: title, items: items.filter(isIncluded))
    }
}

private extension MenuItem {
    var isEntree: Bool {
        category?.containsAny(of: ["entree"]) == true
    }

    var isSoupOrSalad: Bool {
        category?.containsAny(of: MenuKeywords.soupOrSaladStation) == true
            || name.containsAny(of: MenuKeywords.soupOrSaladDish)
    }
}
