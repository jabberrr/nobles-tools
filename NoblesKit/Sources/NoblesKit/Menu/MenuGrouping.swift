import Foundation

extension NutrisliceWeek {
    /// One `DailyMenu` per day, in date order.
    func dailyMenus(meal: Meal) -> [DailyMenu] {
        days.map { $0.dailyMenu(meal: meal) }.sorted { $0.date < $1.date }
    }
}

extension NutrisliceDay {
    /// Groups the day's rows into stations:
    /// - rows are ordered by `position`; a row without one stays after the row before it;
    /// - a header row (section title or station header) with text starts a section;
    /// - any other row with a food name or text is a dish in the current section;
    /// - holiday rows become notes, and blank or icon-only rows are skipped;
    /// - sections without dishes are dropped, except that on a day with no dishes at all their
    ///   titles become notes (e.g. "No Dinner Services");
    /// - a day without any headers is grouped by food category, so filters still have titles.
    func dailyMenu(meal: Meal) -> DailyMenu {
        var sections: [MenuSection] = []
        var notes: [String] = []
        var hasHeaders = false

        for (offset, row) in orderedItems.enumerated() {
            if row.isHoliday, let text = row.text {
                notes.append(text)
            } else if row.isHeader, let text = row.text {
                hasHeaders = true
                sections.append(MenuSection(title: text, items: []))
            } else if let item = row.menuItem(fallbackID: -(offset + 1)) {
                if sections.isEmpty {
                    sections.append(MenuSection(title: "", items: []))
                }
                sections[sections.count - 1].items.append(item)
            }
        }

        if !hasHeaders {
            sections = sections.flatMap(\.items).map { MenuSection(title: Self.sectionTitle(forCategory: $0.category), items: [$0]) }
        }
        let served = sections.filter { !$0.items.isEmpty }
        if served.isEmpty {
            notes += sections.map(\.title).filter { !$0.isEmpty }
        }
        return DailyMenu(date: date, meal: meal, sections: Self.merged(served), notes: Self.unique(notes))
    }

    /// Rows by `position`, keeping each position-less row right after its predecessor.
    private var orderedItems: [NutrisliceItem] {
        var position = Int.min
        return items.enumerated()
            .map { offset, item in
                position = item.position ?? position
                return (position: position, offset: offset, item: item)
            }
            .sorted { ($0.position, $0.offset) < ($1.position, $1.offset) }
            .map(\.item)
    }

    /// "entree" → "Entree"; uncategorized dishes go in an untitled section.
    private static func sectionTitle(forCategory category: String?) -> String {
        guard let category else { return "" }
        return category.replacingOccurrences(of: "_", with: " ").capitalized(with: Locale(identifier: "en_US_POSIX"))
    }

    /// Combines sections that share a title, in first-seen order, so section IDs stay unique.
    private static func merged(_ sections: [MenuSection]) -> [MenuSection] {
        var result: [MenuSection] = []
        var indexByTitle: [String: Int] = [:]
        for section in sections {
            if let index = indexByTitle[section.title] {
                result[index].items += section.items
            } else {
                indexByTitle[section.title] = result.count
                result.append(section)
            }
        }
        return result
    }

    private static func unique(_ notes: [String]) -> [String] {
        var seen: Set<String> = []
        return notes.filter { seen.insert($0).inserted }
    }
}

extension NutrisliceItem {
    /// The dish this row lists, named by its food or else its text; `nil` for a blank row.
    /// `fallbackID` (negative, so it can't clash) is used only if the row has no `id`.
    func menuItem(fallbackID: Int) -> MenuItem? {
        guard let name = food?.name ?? text else { return nil }
        return MenuItem(id: id ?? fallbackID, name: name, category: food?.category ?? category)
    }
}
