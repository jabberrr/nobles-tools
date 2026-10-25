import Foundation

/// A dining-hall meal. Raw values are the default Nutrislice menu-type slugs.
public enum Meal: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }

    public var symbolName: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        }
    }

    /// When service ends (school time). After this a widget moves on to the next menu.
    public var serviceEnds: (hour: Int, minute: Int) {
        switch self {
        case .breakfast: (8, 0)
        case .lunch: (13, 30)
        case .dinner: (19, 0)
        }
    }
}

/// Which meal a menu widget shows.
public enum MealSelection: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Whichever meal is next, moving on as each one ends.
    case upcoming
    case breakfast
    case lunch
    case dinner

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .upcoming: "Next Meal"
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }

    /// The fixed meal, or `nil` for `.upcoming`.
    public var meal: Meal? {
        switch self {
        case .upcoming: nil
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        }
    }
}

/// Which parts of a menu to show.
public enum MenuFilter: Codable, Hashable, Sendable {
    case everything
    /// Only entrées (main dishes).
    case entreesOnly
    /// Everything except salad bars, salads and soups.
    case withoutSaladsAndSoups
    /// Only the named stations/sections ("Just ___").
    case only(sections: [String])
    /// Everything except the named stations/sections.
    case excluding(sections: [String])

    /// Case-free discriminator for pickers.
    public enum Style: String, CaseIterable, Identifiable, Sendable {
        case everything, entreesOnly, withoutSaladsAndSoups, only, excluding

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .everything: "Everything"
            case .entreesOnly: "Just Entrées"
            case .withoutSaladsAndSoups: "No Salads or Soups"
            case .only: "Just…"
            case .excluding: "Everything Except…"
            }
        }
    }

    public var style: Style {
        switch self {
        case .everything: .everything
        case .entreesOnly: .entreesOnly
        case .withoutSaladsAndSoups: .withoutSaladsAndSoups
        case .only: .only
        case .excluding: .excluding
        }
    }

    /// Sections chosen by the user for `.only` / `.excluding`; empty otherwise.
    public var selectedSections: [String] {
        switch self {
        case .only(let sections), .excluding(let sections): sections
        default: []
        }
    }
}

public struct MenuConfiguration: Codable, Hashable, Sendable {
    public var meal: MealSelection
    public var filter: MenuFilter
    /// Show food descriptions under item names (larger sizes only).
    public var showsDescriptions: Bool
    /// Group items under their station names.
    public var showsSectionHeaders: Bool

    public init(
        meal: MealSelection = .lunch,
        filter: MenuFilter = .everything,
        showsDescriptions: Bool = false,
        showsSectionHeaders: Bool = true
    ) {
        self.meal = meal
        self.filter = filter
        self.showsDescriptions = showsDescriptions
        self.showsSectionHeaders = showsSectionHeaders
    }
}

// MARK: - Menu content

/// One meal's menu on one day, grouped into stations/sections.
public struct DailyMenu: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var meal: Meal
    public var sections: [MenuSection]
    /// Free-text notes on the day, e.g. "No school – Thanksgiving".
    public var notes: [String]

    public init(date: LocalDate, meal: Meal, sections: [MenuSection], notes: [String] = []) {
        self.date = date
        self.meal = meal
        self.sections = sections
        self.notes = notes
    }

    public var isEmpty: Bool { sections.allSatisfy(\.items.isEmpty) }
    public var allItems: [MenuItem] { sections.flatMap(\.items) }
}

public struct MenuSection: Codable, Hashable, Identifiable, Sendable {
    /// Station or section title as published, e.g. "Main Entrée". Empty when the menu has no headers.
    public var title: String
    public var items: [MenuItem]

    public init(title: String, items: [MenuItem]) {
        self.title = title
        self.items = items
    }

    public var id: String { title }
}

public struct MenuItem: Codable, Hashable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    public var description: String?
    /// Nutrislice food category, e.g. "entree", "side", "soup".
    public var category: String?
    public var calories: Int?

    public init(id: Int, name: String, description: String? = nil, category: String? = nil, calories: Int? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.calories = calories
    }
}

/// The menu a widget should display right now, and when that choice expires.
public struct UpcomingMenu: Hashable, Sendable {
    public var meal: Meal
    public var date: LocalDate
    /// `nil` when nothing is published for this meal/date (e.g. a weekend or break).
    public var menu: DailyMenu?
    /// When this meal's service ends and the widget should move on.
    public var validUntil: Date

    public init(meal: Meal, date: LocalDate, menu: DailyMenu?, validUntil: Date) {
        self.meal = meal
        self.date = date
        self.menu = menu
        self.validUntil = validUntil
    }
}
