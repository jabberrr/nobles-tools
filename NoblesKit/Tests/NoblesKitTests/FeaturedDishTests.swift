import Foundation
import Testing
@testable import NoblesKit

struct FeaturedDishTests {
    private let monday = LocalDate(2026, 10, 26)
    private let tuesday = LocalDate(2026, 10, 27)
    /// Halloween lunch: themed dishes, a cookie station, and a "Vegan Entree" header with no dishes.
    private let friday = LocalDate(2026, 10, 30)

    @Test func automaticFeaturesTheFirstEntree() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        let dinner = try await MenuFixtures.realMenu(.dinner, on: tuesday)

        #expect(lunch.featuredDish(station: nil)?.name == "Revved Up Macaroni & Cheese")
        #expect(dinner.featuredDish(station: nil)?.name == "Chicken Tikka Masala")
    }

    @Test func aChosenStationMatchesLoosely() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        let halloween = try await MenuFixtures.realMenu(.lunch, on: friday)

        #expect(lunch.featuredDish(station: "Vegan Entree")?.name == "Tomato, Kale, Red Bean & Pasta Toss, Chive Oil")
        #expect(lunch.featuredDish(station: "vegan entrée")?.name == "Tomato, Kale, Red Bean & Pasta Toss, Chive Oil")
        #expect(lunch.featuredDish(station: "Soup")?.name == "Cream of Broccoli & Cheddar Soup")
        #expect(halloween.featuredDish(station: "Dracula's Cookie Extravaganza")?.name == "Chocolate Chip, Snickerdoodle, Oatmeal")
    }

    @Test func aStationThatIsNotServingFallsBackToTheFirstEntree() async throws {
        let halloween = try await MenuFixtures.realMenu(.lunch, on: friday)

        #expect(halloween.featuredDish(station: "Vegan Entree")?.name == "Monster Chicken Fingers")
        #expect(halloween.featuredDish(station: "Pizza")?.name == "Monster Chicken Fingers")
        #expect(halloween.featuredDish(station: "  ")?.name == "Monster Chicken Fingers")
        #expect(DailyMenu(date: friday, meal: .lunch, sections: []).featuredDish(station: "Hot Entree") == nil)
    }

    @Test func automaticFollowsTheFilter() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: tuesday)
        let desserts = MenuConfiguration(filter: .only(sections: ["Dessert"]))

        #expect(desserts.featuredDish(in: lunch)?.name == "Tres Leche Cake")
        #expect(MenuConfiguration(filter: .entreesOnly).featuredDish(in: lunch)?.name == "Turkey Tacos")
    }

    @Test func aChosenStationOverridesTheFilter() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: tuesday)
        let dinner = try await MenuFixtures.realMenu(.dinner, on: tuesday)

        let soupDespiteFilter = MenuConfiguration(filter: .withoutSaladsAndSoups, featuredStation: "Soup Station")
        #expect(soupDespiteFilter.featuredDish(in: lunch)?.name == "Vegetable Tortilla Soup, Crispy Corn Tortilla")
        #expect(MenuConfiguration(featuredStation: "Vegan Option").featuredDish(in: dinner)?.name == "Red Curry Tofu & Bok Choy")
    }

    @Test func theFeaturedStationDecodesLeniently() throws {
        func decode(_ json: String) throws -> MenuConfiguration {
            try JSONDecoder().decode(MenuConfiguration.self, from: Data(json.utf8))
        }

        #expect(try decode(#"{"featuredStation": "Vegan Entree"}"#).featuredStation == "Vegan Entree")
        #expect(try decode(#"{"featuredStation": "  "}"#).featuredStation == nil)
        #expect(try decode(#"{"featuredStation": 3}"#).featuredStation == nil)
        #expect(try decode(#"{"meal": "dinner"}"#) == MenuConfiguration(meal: .dinner))
    }
}
