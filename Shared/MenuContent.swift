import Foundation
import NoblesKit

/// A dish, with the station it's served at.
struct Dish: Hashable {
    let item: MenuItem
    /// The station's title, or empty when the menu has no stations.
    let station: String

    var symbol: String { StationSymbol.name(for: station) }
}

/// What a menu design shows, worked out once from its settings and data for every size.
struct MenuContent {
    enum State {
        /// Nothing could be loaded.
        case unavailable
        /// Nothing is published for this meal; says so, e.g. "No dinner menu today".
        case closed(String)
        /// A menu is published, but the design's filter hides every dish.
        case filteredOut
        /// The featured dish, then the other dishes the filter keeps: as highlights (entrées
        /// first) and by station in menu order.
        case menu(featured: Dish, others: [Dish], stations: [MenuSection])
    }

    let mealName: String
    /// The meal's SF Symbol, without a variant.
    let mealSymbol: String
    /// "Today", "Tomorrow" or "Fri, Oct 30"; `nil` when nothing could be loaded.
    let day: String?
    /// `day` for tight spaces: "Fri".
    let shortDay: String?
    /// Whether to name stations (the design's "Station Names" setting).
    let showsStations: Bool
    /// What the design's filter keeps, e.g. "Just Entrées", for when it hides every dish.
    let filterSummary: String
    let state: State

    /// "No dinner menu", for when the day is shown alongside.
    var noMenuText: String { "No \(mealName.lowercased()) menu" }

    init(configuration: MenuConfiguration, upcoming: UpcomingMenu?, now: Date) {
        let today = LocalDate(now)
        mealName = upcoming?.meal.displayName ?? configuration.meal.displayName
        mealSymbol = (upcoming?.meal ?? configuration.meal.meal)?.symbolName ?? "fork.knife"
        day = upcoming.map { SchoolFormat.relativeDay($0.date, from: today) }
        shortDay = upcoming.map { SchoolFormat.shortRelativeDay($0.date, from: today) }
        showsStations = configuration.showsSectionHeaders
        filterSummary = configuration.filter.summaryText
        state = Self.state(configuration: configuration, upcoming: upcoming, today: today)
    }

    private static func state(configuration: MenuConfiguration, upcoming: UpcomingMenu?, today: LocalDate) -> State {
        guard let upcoming else { return .unavailable }
        guard let menu = upcoming.menu, !menu.isEmpty else { return .closed(closedTitle(upcoming, today: today)) }
        guard let featured = configuration.featuredDish(in: menu) else { return .filteredOut }

        let stationOfDish = Dictionary(
            menu.sections.flatMap { section in section.items.map { ($0.id, section.title) } },
            uniquingKeysWith: { first, _ in first }
        )
        func dish(_ item: MenuItem) -> Dish { Dish(item: item, station: stationOfDish[item.id] ?? "") }

        let filtered = menu.filtered(by: configuration.filter)
        let stations = filtered.sections
            .map { MenuSection(title: $0.title, items: $0.items.filter { $0.id != featured.id }) }
            .filter { !$0.items.isEmpty }
        return .menu(
            featured: dish(featured),
            others: filtered.highlights.filter { $0.id != featured.id }.map(dish),
            stations: stations
        )
    }

    /// "No dinner menu today", "No lunch menu on Sat, Oct 24", "No breakfast menu published".
    private static func closedTitle(_ upcoming: UpcomingMenu, today: LocalDate) -> String {
        let meal = upcoming.meal.displayName.lowercased()
        guard upcoming.meal != .breakfast else { return "No \(meal) menu published" }
        let day = SchoolFormat.relativeDay(upcoming.date, from: today)
        let when = abs(today.days(until: upcoming.date)) <= 1 ? day.lowercased() : "on \(day)"
        return "No \(meal) menu \(when)"
    }
}

extension MenuFilter {
    /// A readable description, e.g. "Just Hot Entree, Dessert" or "Everything except Soup Station".
    /// With no stations chosen, "Just…" and "Everything Except…" filter nothing: "All stations".
    var summaryText: String {
        switch self {
        case .everything, .entreesOnly, .withoutSaladsAndSoups:
            style.displayName
        case .only(let sections):
            sections.isEmpty ? "All stations" : "Just " + sections.joined(separator: ", ")
        case .excluding(let sections):
            sections.isEmpty ? "All stations" : "Everything except " + sections.joined(separator: ", ")
        }
    }
}

extension UpcomingMenu {
    /// Sample content for placeholders and offline previews.
    static func placeholder(for selection: MealSelection, now: Date = .now) -> UpcomingMenu {
        let meal = selection.meal ?? .lunch
        let date = LocalDate(now)
        return UpcomingMenu(
            meal: meal,
            date: date,
            menu: .sample(meal: meal, date: date),
            validUntil: meal.serviceEnd(on: date)
        )
    }
}
