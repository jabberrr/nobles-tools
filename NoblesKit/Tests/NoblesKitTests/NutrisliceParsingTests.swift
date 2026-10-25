import Foundation
import Testing
@testable import NoblesKit

/// Decoding and grouping, mostly against the real captured week of 2026-10-25.
struct NutrisliceParsingTests {
    private func sections(_ menu: DailyMenu) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: menu.sections.map { ($0.title, $0.items.map(\.name)) })
    }

    @Test func weekRunsSundayThroughSaturday() async throws {
        let http = FakeHTTPClient(try MenuFixtures.realResponses())
        let service = MenuService(http: http, cache: nil)
        let week = try await service.week(containing: LocalDate(2026, 10, 31), meal: .lunch)

        #expect(week.map(\.date) == (0..<7).map { LocalDate(2026, 10, 25).adding(days: $0) })
        #expect(week.first?.isEmpty == true)
        #expect(week.last?.isEmpty == true)
        #expect(await http.requestCount(for: MenuFixtures.weekURL(.lunch, monday: MenuFixtures.capturedMonday)) == 1)
    }

    @Test func groupsRealLunchByStation() async throws {
        let menu = try await MenuFixtures.realMenu(.lunch, on: LocalDate(2026, 10, 26))

        #expect(menu.sections.map(\.title) == ["Soup Station", "Hot Entree", "Vegan Entree", "Sides", "Weekly Composed Salad"])
        // The icon-only row ("Rev") before the dish is skipped.
        #expect(sections(menu)["Hot Entree"] == ["Revved Up Macaroni & Cheese"])
        #expect(sections(menu)["Sides"] == ["Warm Bread Sticks", "Roasted Green Beans with Shallots"])
        #expect(menu.sections[1].items.first?.id == 422953990)
        #expect(menu.notes.isEmpty)
    }

    @Test func readsDishesFromFoodObjects() async throws {
        let menu = try await MenuFixtures.realMenu(.lunch, on: LocalDate(2026, 10, 28))
        let sides = try #require(menu.sections.first { $0.title == "Sides" })

        #expect(sides.items.map(\.name) == ["Sweet Potato Fries", "Cilantro Steamed Carrots, Chili Oil"])
        #expect(sides.items[0] == MenuItem(id: 430782744, name: "Sweet Potato Fries"))
    }

    @Test func dropsStationsWithoutDishes() async throws {
        let menu = try await MenuFixtures.realMenu(.lunch, on: LocalDate(2026, 10, 30))

        #expect(menu.sections.map(\.title) == ["Soup Station", "Hot Entree", "Sides", "Dracula's Cookie Extravaganza", "Weekly Composed Salad"])
        #expect(menu.notes.isEmpty)
    }

    @Test func dayWithoutDishesKeepsHeadersAsNotes() async throws {
        let menu = try await MenuFixtures.realMenu(.dinner, on: LocalDate(2026, 10, 30))

        #expect(menu.isEmpty)
        #expect(menu.notes == ["No Dinner Services"])
    }

    @Test func groupsRealDinner() async throws {
        let menu = try await MenuFixtures.realMenu(.dinner, on: LocalDate(2026, 10, 26))

        #expect(menu.meal == .dinner)
        #expect(menu.sections.map(\.title) == ["Hot Entree", "Sides", "Vegan Option", "Dessert"])
        #expect(sections(menu)["Hot Entree"] == ["Cordon Bleu Style Chicken", "Herb Veloute"])
    }

    // MARK: Synthetic edge cases

    private func edgeCaseWeek() throws -> [DailyMenu] {
        try NutrisliceWeek.decoded(from: Fixture.data("synthetic-edge-cases-week.json")).dailyMenus(meal: .lunch)
    }

    @Test func skipsMalformedDays() throws {
        let dates = try edgeCaseWeek().map(\.date)
        #expect(dates == [LocalDate(2026, 11, 22), LocalDate(2026, 11, 23), LocalDate(2026, 11, 24), LocalDate(2026, 11, 25), LocalDate(2026, 11, 28)])
    }

    @Test func toleratesOddRows() throws {
        let menu = try #require(try edgeCaseWeek().first { $0.date == LocalDate(2026, 11, 23) })

        // Rows are sorted by position (a string position still counts, a missing one stays after
        // its predecessor), a non-object row is skipped, the empty "Vegan Entree" is dropped and
        // the repeated "Sides" header is merged.
        #expect(menu.sections.map(\.title) == ["Hot Entree", "Sides"])
        #expect(sections(menu)["Hot Entree"] == ["Turkey Pot Pie", "Gravy"])
        #expect(sections(menu)["Sides"] == ["Sweet Potato Fries", "Garlic Knots", "Cranberry Sauce", "Steamed Green Beans"])

        let sides = menu.sections[1].items
        #expect(sides[0] == MenuItem(id: 9004, name: "Sweet Potato Fries"))
        #expect(sides[1].id == 9005)
        #expect(sides[2].id < 0)
    }

    @Test func groupsHeaderlessDaysByCategory() throws {
        let menu = try #require(try edgeCaseWeek().first { $0.date == LocalDate(2026, 11, 24) })

        #expect(menu.sections.map(\.title) == ["Entree", "Side", "", "Soup", "Salad Bar", "Dessert"])
        #expect(sections(menu)["Side"] == ["Mashed Potatoes", "Herb Stuffing"])
        #expect(menu.sections[0].items == [
            MenuItem(id: 9101, name: "Roast Turkey", category: "entree"),
        ])
    }

    @Test func holidayRowsBecomeNotes() throws {
        let week = try edgeCaseWeek()
        let holiday = try #require(week.first { $0.date == LocalDate(2026, 11, 25) })

        #expect(holiday.isEmpty)
        #expect(holiday.notes == ["No School – Thanksgiving Break"])
        #expect(week.last?.isEmpty == true)
    }

    @Test func rejectsResponsesThatAreNotWeeks() {
        #expect(throws: MenuServiceError.self) {
            try NutrisliceWeek.decoded(from: Data(#"{"detail": "Not found."}"#.utf8))
        }
        #expect(throws: MenuServiceError.self) {
            try NutrisliceWeek.decoded(from: Data("<html></html>".utf8))
        }
    }
}
