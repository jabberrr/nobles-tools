import Foundation
import Testing
@testable import NoblesKit

struct MenuServiceTests {
    private let captured = MenuFixtures.capturedMonday
    private let next = MenuFixtures.nextMonday

    /// The real captured week, plus a next week with one lunch and one dinner on Monday 11/2.
    private func responses() throws -> [URL: FakeHTTPClient.Response] {
        var responses = try MenuFixtures.realResponses()
        responses[MenuFixtures.weekURL(.lunch, monday: next)] = .data(try MenuFixtures.week(monday: next, dishes: [next: "Chicken Parmesan"]))
        responses[MenuFixtures.weekURL(.dinner, monday: next)] = .data(try MenuFixtures.week(monday: next, dishes: [next: "Beef Stir Fry"]))
        return responses
    }

    private func at(_ date: LocalDate, _ hour: Int, _ minute: Int = 0) -> Date {
        date.at(hour: hour, minute: minute)
    }

    // MARK: Endpoint

    @Test func formatsEndpointURLs() {
        let endpoint = MenuEndpoint.nobles
        #expect(endpoint.weekURL(menuType: "lunch", date: LocalDate(2026, 1, 5)).absoluteString
            == "https://nobleandgreenough.api.flikisdining.com/menu/api/weeks/school/noble-and-greenough-school/menu-type/lunch/2026/01/05/")
        #expect(endpoint.schoolsURL.absoluteString == "https://nobleandgreenough.api.flikisdining.com/menu/api/schools/")
    }

    @Test func requestsEachWeekByItsMonday() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)
        _ = try await service.week(containing: LocalDate(2026, 10, 25), meal: .lunch)
        _ = try await service.week(containing: LocalDate(2026, 10, 31), meal: .lunch)

        #expect(await http.requestCount(for: MenuFixtures.weekURL(.lunch, monday: captured)) == 2)
    }

    // MARK: Menu types

    @Test func discoversLunchAndDinner() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)

        #expect(try await service.availableMeals() == [.lunch, .dinner])
        #expect(try await service.week(containing: captured, meal: .breakfast).isEmpty)
        #expect(try await service.menu(on: captured, meal: .breakfast) == nil)
        #expect(await http.requests.allSatisfy { !$0.absoluteString.contains("breakfast") })
    }

    @Test func usesDiscoveredSlugs() async throws {
        let schools = #"""
        [{"slug": "other-school", "active_menu_types": [{"name": "Breakfast", "slug": "wrong"}]},
         {"slug": "noble-and-greenough-school", "active_menu_types": [
            {"name": "Breakfast", "slug": "morning"}, {"name": "Lunch Menu", "slug": "lunch-menu"}, 42]}]
        """#
        let http = FakeHTTPClient([MenuFixtures.endpoint.schoolsURL: .data(Data(schools.utf8))])
        let service = MenuService(http: http, cache: nil)

        #expect(try await service.availableMeals() == [.breakfast, .lunch])
        _ = try? await service.week(containing: captured, meal: .lunch)
        let lunchMenuURL = MenuFixtures.endpoint.weekURL(menuType: "lunch-menu", date: captured)
        #expect(await http.requestCount(for: lunchMenuURL) == 1)
    }

    @Test(arguments: [
        FakeHTTPClient.Response.failure(Offline()),
        .data(Data(#"[{"slug": "another-school", "active_menu_types": []}]"#.utf8)),
        .data(Data("<html></html>".utf8)),
    ])
    func fallsBackToKnownMealsWhenDiscoveryFails(schools: FakeHTTPClient.Response) async throws {
        let service = MenuService(http: FakeHTTPClient([MenuFixtures.endpoint.schoolsURL: schools]), cache: nil)
        #expect(try await service.availableMeals() == [.lunch, .dinner])
    }

    @Test func cachesMenuTypesForAWeek() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let http = FakeHTTPClient(try responses())
        let schoolsURL = MenuFixtures.endpoint.schoolsURL

        _ = try await MenuService(http: http, cache: cache).availableMeals()
        _ = try await MenuService(http: http, cache: cache).availableMeals()
        #expect(await http.requestCount(for: schoolsURL) == 1)

        let service = MenuService(http: http, cache: cache)
        let cached = try #require(await cache.data(for: service.menuTypesCacheKey))
        await cache.store(cached.data, for: service.menuTypesCacheKey, savedAt: .now - 8 * 24 * 60 * 60)
        _ = try await service.availableMeals()
        #expect(await http.requestCount(for: schoolsURL) == 2)
    }

    // MARK: Upcoming menu

    @Test func fixedMealShowsTodayUntilServiceEnds() async throws {
        let service = MenuService(http: FakeHTTPClient(try responses()), cache: nil)
        let upcoming = try await service.upcomingMenu(for: .lunch, now: at(captured, 11))

        #expect(upcoming.meal == .lunch)
        #expect(upcoming.date == captured)
        #expect(upcoming.validUntil == at(captured, 13, 30))
        #expect(upcoming.menu?.sections.first?.title == "Soup Station")
    }

    @Test func fixedMealMovesOnWhenServiceEnds() async throws {
        let service = MenuService(http: FakeHTTPClient(try responses()), cache: nil)
        let upcoming = try await service.upcomingMenu(for: .lunch, now: at(captured, 13, 30))

        #expect(upcoming.date == LocalDate(2026, 10, 27))
        #expect(upcoming.menu?.allItems.contains { $0.name == "Turkey Tacos" } == true)
    }

    @Test func fixedMealSkipsTheWeekend() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)
        let upcoming = try await service.upcomingMenu(for: .lunch, now: at(LocalDate(2026, 10, 30), 14))

        #expect(upcoming.date == next)
        #expect(upcoming.menu?.allItems.map(\.name) == ["Chicken Parmesan"])
        #expect(await http.requestCount(for: MenuFixtures.weekURL(.lunch, monday: captured)) == 1)
        #expect(await http.requestCount(for: MenuFixtures.weekURL(.lunch, monday: next)) == 1)
    }

    @Test func nextMealFollowsServingOrder() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)

        let morning = try await service.upcomingMenu(for: .upcoming, now: at(captured, 6, 30))
        #expect(morning.meal == .lunch)
        #expect(morning.date == captured)

        let afternoon = try await service.upcomingMenu(for: .upcoming, now: at(captured, 14))
        #expect(afternoon.meal == .dinner)
        #expect(afternoon.validUntil == at(captured, 19))
        #expect(afternoon.menu?.sections.first?.items.first?.name == "Cordon Bleu Style Chicken")

        let night = try await service.upcomingMenu(for: .upcoming, now: at(captured, 19))
        #expect(night.meal == .lunch)
        #expect(night.date == LocalDate(2026, 10, 27))

        #expect(await http.requests.allSatisfy { !$0.absoluteString.contains("breakfast") })
    }

    @Test func nextMealSkipsADayWithoutDinner() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)
        let upcoming = try await service.upcomingMenu(for: .upcoming, now: at(LocalDate(2026, 10, 30), 14))

        // Friday's dinner is only "No Dinner Services" and the weekend is empty. Sunday starts the
        // next week, so each meal's next week is loaded (once) on the way to Monday's lunch.
        #expect(upcoming.meal == .lunch)
        #expect(upcoming.date == next)
        #expect(upcoming.menu?.allItems.map(\.name) == ["Chicken Parmesan"])
        for monday in [captured, next] {
            for meal in [Meal.lunch, .dinner] {
                #expect(await http.requestCount(for: MenuFixtures.weekURL(meal, monday: monday)) == 1)
            }
        }
    }

    @Test func unavailableMealReturnsNoMenuWithoutFetching() async throws {
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: nil)

        let early = try await service.upcomingMenu(for: .breakfast, now: at(captured, 7))
        #expect(early == UpcomingMenu(meal: .breakfast, date: captured, menu: nil, validUntil: LocalDate(2026, 10, 27).startOfDay()))
        let late = try await service.upcomingMenu(for: .breakfast, now: at(captured, 9))
        #expect(late.date == LocalDate(2026, 10, 27))
        #expect(await http.requests == [MenuFixtures.endpoint.schoolsURL, MenuFixtures.endpoint.schoolsURL])
    }

    @Test func returnsNoMenuWhenNothingIsPublished() async throws {
        let http = FakeHTTPClient([
            MenuFixtures.weekURL(.lunch, monday: captured): .data(try MenuFixtures.week(monday: captured)),
            MenuFixtures.weekURL(.lunch, monday: next): .data(try MenuFixtures.week(monday: next)),
        ])
        let service = MenuService(http: http, cache: nil)
        let upcoming = try await service.upcomingMenu(for: .lunch, now: at(captured, 10))

        #expect(upcoming == UpcomingMenu(meal: .lunch, date: captured, menu: nil, validUntil: LocalDate(2026, 10, 27).startOfDay()))
        #expect(await http.requests.count == 3)
    }

    @Test func throwsWhenNoWeekLoads() async throws {
        var responses = try responses()
        for monday in [captured, next] {
            responses[MenuFixtures.weekURL(.lunch, monday: monday)] = .failure(HTTPError.status(500))
        }
        let service = MenuService(http: FakeHTTPClient(responses), cache: nil)

        await #expect(throws: HTTPError.status(500)) {
            try await service.upcomingMenu(for: .lunch, now: at(captured, 10))
        }
    }

    @Test func oneFailingMealDoesNotHideTheOthers() async throws {
        var responses = try responses()
        responses[MenuFixtures.weekURL(.dinner, monday: captured)] = .failure(HTTPError.status(500))
        let service = MenuService(http: FakeHTTPClient(responses), cache: nil)
        let upcoming = try await service.upcomingMenu(for: .upcoming, now: at(captured, 14))

        #expect(upcoming.meal == .lunch)
        #expect(upcoming.date == LocalDate(2026, 10, 27))
    }

    // MARK: Caching

    @Test func usesTheCachedWeekWhenOffline() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let now = at(captured, 11)
        let online = try await MenuService(http: FakeHTTPClient(try responses()), cache: cache).upcomingMenu(for: .lunch, now: now)

        var offline: [URL: FakeHTTPClient.Response] = [:]
        for url in try responses().keys {
            offline[url] = .failure(Offline())
        }
        let cached = try await MenuService(http: FakeHTTPClient(offline), cache: cache).upcomingMenu(for: .lunch, now: now)

        #expect(cached == online)
        #expect(cached.menu != nil)
    }

    @Test func badResponsesDoNotUseOrReplaceTheCache() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let http = FakeHTTPClient(try responses())
        let service = MenuService(http: http, cache: cache)
        let good = try await service.week(containing: captured, meal: .lunch)

        let url = MenuFixtures.weekURL(.lunch, monday: captured)
        await http.respond(to: url, with: .data(Data("<html>Maintenance</html>".utf8)))
        await #expect(throws: MenuServiceError.self) {
            try await service.week(containing: captured, meal: .lunch)
        }

        await http.respond(to: url, with: .failure(Offline()))
        #expect(try await service.week(containing: captured, meal: .lunch) == good)
    }

    // MARK: Section titles

    @Test func listsStationTitlesInOrderOfAppearance() async throws {
        // Only the captured week is available; the following week's request fails.
        let service = MenuService(http: FakeHTTPClient(try MenuFixtures.realResponses()), cache: nil)

        let lunch = try await service.sectionTitles(for: .lunch, around: captured)
        #expect(lunch == ["Soup Station", "Hot Entree", "Vegan Entree", "Sides", "Weekly Composed Salad", "Dessert", "Dracula's Cookie Extravaganza"])
        let all = try await service.sectionTitles(for: nil, around: captured)
        #expect(all == lunch + ["Vegan Option"])
        #expect(try await service.sectionTitles(for: .breakfast, around: captured).isEmpty)
    }

    @Test func sectionTitlesThrowWhenNothingLoads() async throws {
        let service = MenuService(http: FakeHTTPClient([MenuFixtures.endpoint.schoolsURL: .failure(Offline())]), cache: nil)
        await #expect(throws: HTTPError.status(404)) {
            try await service.sectionTitles(for: .lunch, around: captured)
        }
    }
}
