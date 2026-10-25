import Foundation

extension DailyMenu {
    /// The menu narrowed to what `filter` asks for. Station titles and dish names match ignoring
    /// case and accents ("Entrée" == "entree"). Notes are always kept; empty sections are dropped.
    ///
    /// Nobles' categories are always empty, so the built-in filters go by station title first:
    /// - `.entreesOnly`: stations named "…Entree…" or "…Main…", or ending in "Option" (dinner's
    ///   "Vegan Option"), plus entrée-category dishes from other stations. If nothing qualifies,
    ///   the first station is shown so the widget isn't blank.
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
            let entrees = sections.map { $0.isEntreeStation ? $0 : $0.keeping(\.isEntree) }.filter { !$0.items.isEmpty }
            return entrees.isEmpty ? Array(sections.lazy.filter { !$0.items.isEmpty }.prefix(1)) : entrees
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
}

private enum MenuKeywords {
    static let entreeStation = ["entree", "main"]
    static let soupOrSaladStation = ["soup", "salad"]
    static let soupOrSaladDish = ["soup", "salad", "chowder", "bisque", "gazpacho"]

    /// The user's chosen station names as match keys, without blanks.
    static func selection(_ names: [String]) -> [String] {
        names.map(\.matchKey).filter { !$0.isEmpty }
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
