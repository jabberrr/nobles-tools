import Foundation
import Testing
@testable import NoblesKit

struct MenuFilteringTests {
    private let monday = LocalDate(2026, 10, 26)

    private func titles(_ menu: DailyMenu, _ filter: MenuFilter) -> [String] {
        menu.filtered(by: filter).sections.map(\.title)
    }

    @Test func everythingKeepsTheMenu() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        #expect(lunch.filtered(by: .everything) == lunch)
    }

    @Test func entreesOnlyUsesStationTitles() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        let dinner = try await MenuFixtures.realMenu(.dinner, on: LocalDate(2026, 10, 27))

        #expect(titles(lunch, .entreesOnly) == ["Hot Entree", "Vegan Entree"])
        #expect(titles(dinner, .entreesOnly) == ["Hot Entree", "Vegan Option"])
    }

    @Test func entreesOnlyKeepsEntreeDishesFromOtherStations() {
        let menu = DailyMenu(date: monday, meal: .lunch, sections: [
            MenuSection(title: "Grill", items: [
                MenuItem(id: 1, name: "Cheeseburger", category: "Entrée"),
                MenuItem(id: 2, name: "Fries", category: "side"),
            ]),
            MenuSection(title: "Main Plate", items: [MenuItem(id: 3, name: "Roast Chicken")]),
        ])

        let filtered = menu.filtered(by: .entreesOnly)
        #expect(filtered.sections.map(\.title) == ["Grill", "Main Plate"])
        #expect(filtered.allItems.map(\.name) == ["Cheeseburger", "Roast Chicken"])
    }

    @Test func entreesOnlyFallsBackToTheFirstStation() {
        let menu = DailyMenu(date: monday, meal: .breakfast, sections: [
            MenuSection(title: "Bakery", items: []),
            MenuSection(title: "Hot Breakfast", items: [MenuItem(id: 1, name: "Scrambled Eggs")]),
            MenuSection(title: "Fruit", items: [MenuItem(id: 2, name: "Melon")]),
        ])
        #expect(titles(menu, .entreesOnly) == ["Hot Breakfast"])
    }

    @Test func withoutSaladsAndSoupsDropsStationsAndDishes() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        let dinner = try await MenuFixtures.realMenu(.dinner, on: LocalDate(2026, 10, 28))

        #expect(titles(lunch, .withoutSaladsAndSoups) == ["Hot Entree", "Vegan Entree", "Sides"])
        let sides = dinner.filtered(by: .withoutSaladsAndSoups).sections.first { $0.title == "Sides" }
        #expect(sides?.items.map(\.name) == ["Yeti's Yuk Steamed Spinach"])
    }

    @Test func withoutSaladsAndSoupsUsesCategoriesAndDishNames() {
        let menu = DailyMenu(date: monday, meal: .lunch, sections: [
            MenuSection(title: "Specials", items: [
                MenuItem(id: 1, name: "Clam Chowder"),
                MenuItem(id: 2, name: "Tomato Bisque"),
                MenuItem(id: 3, name: "Chef's Choice", category: "soup"),
                MenuItem(id: 4, name: "Fish Tacos"),
            ]),
        ])
        #expect(menu.filtered(by: .withoutSaladsAndSoups).allItems.map(\.name) == ["Fish Tacos"])
    }

    @Test func onlyMatchesTitlesLoosely() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)

        #expect(titles(lunch, .only(sections: ["hot entrée"])) == ["Hot Entree"])
        #expect(titles(lunch, .only(sections: ["Entree"])) == ["Hot Entree", "Vegan Entree"])
        #expect(titles(lunch, .only(sections: ["Soup Station Specials", "SIDES"])) == ["Soup Station", "Sides"])
        #expect(titles(lunch, .only(sections: ["Dessert"])).isEmpty)
        #expect(lunch.filtered(by: .only(sections: [])) == lunch)
        #expect(lunch.filtered(by: .only(sections: ["  "])) == lunch)
    }

    @Test func excludingRemovesChosenStations() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)

        #expect(titles(lunch, .excluding(sections: ["sides", "Weekly Composed Salad"])) == ["Soup Station", "Hot Entree", "Vegan Entree"])
        #expect(lunch.filtered(by: .excluding(sections: [])) == lunch)
    }

    @Test func untitledSectionsAreNeverChosen() {
        let menu = DailyMenu(date: monday, meal: .lunch, sections: [
            MenuSection(title: "", items: [MenuItem(id: 1, name: "Dinner Rolls")]),
            MenuSection(title: "Deli", items: [MenuItem(id: 2, name: "Turkey Club")]),
        ])
        #expect(titles(menu, .only(sections: ["Deli"])) == ["Deli"])
        #expect(titles(menu, .excluding(sections: ["Deli"])) == [""])
    }

    @Test(arguments: [
        MenuFilter.everything, .entreesOnly, .withoutSaladsAndSoups, .only(sections: ["Deli"]), .excluding(sections: ["Deli"]),
    ])
    func keepsNotesAndDropsEmptySections(filter: MenuFilter) {
        let menu = DailyMenu(
            date: monday,
            meal: .lunch,
            sections: [MenuSection(title: "Soup", items: []), MenuSection(title: "Deli", items: [MenuItem(id: 1, name: "BLT")])],
            notes: ["Early dismissal"]
        )
        let filtered = menu.filtered(by: filter)
        #expect(filtered.notes == ["Early dismissal"])
        #expect(filtered.sections.allSatisfy { !$0.items.isEmpty })
    }
}
