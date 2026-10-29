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

        #expect(MenuConfiguration().featuredDish(in: lunch)?.name == "Revved Up Macaroni & Cheese")
        #expect(MenuConfiguration().featuredDish(in: dinner)?.name == "Chicken Tikka Masala")
    }

    @Test func stationsMatchLoosely() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: monday)
        let halloween = try await MenuFixtures.realMenu(.lunch, on: friday)

        #expect(lunch.firstDish(atStation: "Vegan Entree")?.name == "Tomato, Kale, Red Bean & Pasta Toss, Chive Oil")
        #expect(lunch.firstDish(atStation: "vegan entrée")?.name == "Tomato, Kale, Red Bean & Pasta Toss, Chive Oil")
        #expect(lunch.firstDish(atStation: "Soup")?.name == "Cream of Broccoli & Cheddar Soup")
        #expect(halloween.firstDish(atStation: "Dracula's Cookie Extravaganza")?.name == "Chocolate Chip, Snickerdoodle, Oatmeal")
    }

    @Test func stationsMatchAcrossMealsByTheirDistinctiveWords() async throws {
        let lunch = try await MenuFixtures.realMenu(.lunch, on: tuesday)
        let dinner = try await MenuFixtures.realMenu(.dinner, on: tuesday)

        #expect(dinner.firstDish(atStation: "Vegan Entree")?.name == "Red Curry Tofu & Bok Choy")
        #expect(lunch.firstDish(atStation: "Vegan Option")?.name == "Chili-Cumin Root Vegetable Taco Medley")
        #expect(dinner.firstDish(atStation: "Hot Entree")?.name == "Chicken Tikka Masala")
        #expect(dinner.firstDish(atStation: "Weekly Composed Salad") == nil)
    }

    @Test func stationsThatAreNotServingHaveNoDish() async throws {
        let halloween = try await MenuFixtures.realMenu(.lunch, on: friday)

        #expect(halloween.firstDish(atStation: "Vegan Entree") == nil)
        #expect(halloween.firstDish(atStation: "Pizza") == nil)
        #expect(halloween.firstDish(atStation: "  ") == nil)
    }

    @Test func aStationThatIsNotServingFallsBackToTheFilteredMenu() async throws {
        let halloween = try await MenuFixtures.realMenu(.lunch, on: friday)
        let noHotEntree = MenuConfiguration(filter: .excluding(sections: ["Hot Entree"]), featuredStation: "Vegan Entree")

        #expect(MenuConfiguration(featuredStation: "Vegan Entree").featuredDish(in: halloween)?.name == "Monster Chicken Fingers")
        #expect(noHotEntree.featuredDish(in: halloween)?.name == "Black Widow Soup, Sour Cream & Scallions")
        #expect(MenuConfiguration(featuredStation: "Vegan Entree").featuredDish(in: DailyMenu(date: friday, meal: .lunch, sections: [])) == nil)
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
