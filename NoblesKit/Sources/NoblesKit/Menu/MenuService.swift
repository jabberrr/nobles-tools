import Foundation

public enum MenuServiceError: Error, Equatable {
    /// The response wasn't a Nutrislice week.
    case decoding(String)
}

/// Loads dining-hall menus from Nutrislice. Responses are cached, so when the network fails the
/// last good copy is used. Meals the school doesn't publish (see `availableMeals()`) are never
/// requested.
public struct MenuService: Sendable {
    /// How many days ahead `upcomingMenu(for:now:)` looks for a published menu.
    static let searchDays = 10

    let fetcher: CachingFetcher
    let endpoint: MenuEndpoint

    public init(http: any HTTPClient = URLSessionHTTPClient(), endpoint: MenuEndpoint = .nobles, cache: ResponseCache? = .shared) {
        fetcher = CachingFetcher(http: http, cache: cache)
        self.endpoint = endpoint
    }

    /// The meals the school publishes, in serving order, discovered from its menu types and
    /// refreshed weekly. Lunch and dinner when discovery fails.
    public func availableMeals() async -> [Meal] {
        await menuTypes().meals
    }

    /// Every day the week endpoint returns for the week containing `date` (Nutrislice weeks run
    /// Sunday–Saturday), in date order. Empty for a meal the school doesn't publish.
    public func week(containing date: LocalDate, meal: Meal) async throws -> [DailyMenu] {
        guard let slug = await menuTypes().slug(for: meal) else { return [] }
        return try await week(containing: date, meal: meal, slug: slug)
    }

    /// What a menu widget should show at `now`:
    /// - a fixed meal shows today's menu until its service ends, then the next day that has one;
    /// - `.upcoming` shows the next published meal in serving order, skipping meals already over.
    ///
    /// Searches up to 10 days, fetching each meal's week once. A week that fails to load counts as
    /// empty so one menu type can't hide the others; the error is thrown only if nothing loaded.
    /// When nothing is published (or the meal isn't offered), returns the next day the meal could
    /// be served with `menu == nil`, valid until the midnight after it so the widget checks again.
    public func upcomingMenu(for selection: MealSelection, now: Date = .now) async throws -> UpcomingMenu {
        try await upcomingMenus(for: selection, now: now, limit: 1)[0]
    }

    /// The menu to show at `now`, followed by the menus that replace it as each one's service
    /// ends: every element is what `upcomingMenu(for:now:)` returns at the previous one's
    /// `validUntil`. Never empty, and at most `limit` long. Weeks are fetched once for the whole
    /// list; if a later menu can't be loaded the list ends before it, so only the first throws.
    public func upcomingMenus(for selection: MealSelection, now: Date = .now, limit: Int = 2) async throws -> [UpcomingMenu] {
        var loader = WeekLoader(service: self, types: await menuTypes())
        var menus = [try await upcomingMenu(for: selection, now: now, loader: &loader)]
        while menus.count < limit,
              let next = try? await upcomingMenu(for: selection, now: menus[menus.count - 1].validUntil, loader: &loader) {
            menus.append(next)
        }
        return menus
    }

    /// Distinct station titles for `meal` (every published meal when `nil`) over the week
    /// containing `date` and the next, in order of first appearance. For "Just…" pickers.
    public func sectionTitles(for meal: Meal?, around date: LocalDate) async throws -> [String] {
        let types = await menuTypes()
        var loader = WeekLoader(service: self, types: types)
        var titles: [String] = []
        var seen: Set<String> = []
        for meal in meal.map({ [$0] }) ?? types.meals {
            for weekDate in [date, date.adding(days: 7)] {
                for section in await loader.week(containing: weekDate, meal: meal).flatMap(\.sections) where !section.title.isEmpty {
                    if seen.insert(section.title.matchKey).inserted {
                        titles.append(section.title)
                    }
                }
            }
        }
        try loader.rethrowIfNothingLoaded()
        return titles
    }

    /// Requests the week by its Monday, which is inside the published week whether Nutrislice
    /// starts weeks on Sunday (as it does) or Monday, and gives every day of a week the same URL
    /// so cached copies are shared.
    func week(containing date: LocalDate, meal: Meal, slug: String) async throws -> [DailyMenu] {
        let url = endpoint.weekURL(menuType: slug, date: date.mondayOfWeek)
        return try await fetcher.fetch(url) { try NutrisliceWeek.decoded(from: $0).dailyMenus(meal: meal) }.value
    }

    /// One `upcomingMenu(for:now:)` search, reusing the weeks `loader` already has.
    private func upcomingMenu(for selection: MealSelection, now: Date, loader: inout WeekLoader) async throws -> UpcomingMenu {
        let meals = (selection.meal.map { [$0] } ?? Meal.allCases).filter { loader.types.slug(for: $0) != nil }
        let today = LocalDate.today(now: now)
        loader.startSearch()

        if !meals.isEmpty {
            let firstDay = meals.contains { now < $0.serviceEnd(on: today) } ? today : today.adding(days: 1)
            for date in (0..<Self.searchDays).map(firstDay.adding(days:)) {
                for meal in meals where now < meal.serviceEnd(on: date) {
                    if let menu = await loader.menu(on: date, meal: meal) {
                        return UpcomingMenu(meal: meal, date: date, menu: menu, validUntil: meal.serviceEnd(on: date))
                    }
                }
            }
            try loader.rethrowIfNothingLoaded()
        }

        let meal = selection.meal ?? .lunch
        let date = now < meal.serviceEnd(on: today) ? today : today.adding(days: 1)
        return UpcomingMenu(meal: meal, date: date, menu: nil, validUntil: date.adding(days: 1).startOfDay())
    }
}

/// Loads each (meal, week) at most once, across one or more searches. A failed week counts as
/// empty, and `rethrowIfNothingLoaded()` throws the first failure when none of the weeks used
/// since `startSearch()` loaded.
private struct WeekLoader {
    private struct Key: Hashable {
        var meal: Meal
        var monday: LocalDate
    }

    let service: MenuService
    let types: MenuTypes
    private var weeks: [Key: Result<[DailyMenu], any Error>] = [:]
    private var loadedAny = false
    private var firstError: (any Error)?

    init(service: MenuService, types: MenuTypes) {
        self.service = service
        self.types = types
    }

    /// Begins a new search: `rethrowIfNothingLoaded()` then considers only weeks used from here on.
    mutating func startSearch() {
        loadedAny = false
        firstError = nil
    }

    mutating func week(containing date: LocalDate, meal: Meal) async -> [DailyMenu] {
        guard let slug = types.slug(for: meal) else { return [] }
        let key = Key(meal: meal, monday: date.mondayOfWeek)
        let result: Result<[DailyMenu], any Error>
        if let loaded = weeks[key] {
            result = loaded
        } else {
            do {
                result = .success(try await service.week(containing: date, meal: meal, slug: slug))
            } catch {
                result = .failure(error)
            }
            weeks[key] = result
        }
        switch result {
        case .success(let week):
            loadedAny = true
            return week
        case .failure(let error):
            firstError = firstError ?? error
            return []
        }
    }

    mutating func menu(on date: LocalDate, meal: Meal) async -> DailyMenu? {
        await week(containing: date, meal: meal).first { $0.date == date && !$0.isEmpty }
    }

    func rethrowIfNothingLoaded() throws {
        if !loadedAny, let firstError { throw firstError }
    }
}

private extension LocalDate {
    /// The Monday of the Sunday–Saturday week containing this day.
    var mondayOfWeek: LocalDate { adding(days: 2 - weekday) }
}
