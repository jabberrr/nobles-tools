import Testing
@testable import NoblesKit

struct CafeItemArtTests {
    @Test(arguments: [
        // The head noun wins over the flavors and fillings named before it.
        ("Oatmeal Raisin Cookie", "🍪"),
        ("Apple Cinnamon Oatmeal", "🥣"),
        ("Pumpkin Bread", "🍞"),
        ("Kettle Chips", "🥔"),
        ("Orange Juice", "🧃"),
        // A phrase beats the word it ends with.
        ("Hot Chocolate", "☕️"),
        ("Ice Cream Sandwich", "🍦"),
        ("Coconut Water", "🥥"),
        ("Matcha Latte", "🍵"),
        ("Fruit Salad", "🍇"),
        // "with …" lists trimmings.
        ("Everything Bagel with Butter", "🥯"),
        ("Roasted Turkey & Cheddar Panini with Pesto", "🥪"),
        ("Bagel w/ Cream Cheese", "🥯"),
        ("Plate with Chicken", "🍗"), // nothing before "with", so the whole name counts
    ])
    func picksTheMostSpecificKeyword(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test(arguments: [
        // Hot drinks…
        ("Vanilla Latte", "☕️"),
        ("Hot Chocolate", "☕️"),
        ("Matcha Latte", "🍵"),
        ("Chai Tea", "🍵"),
        ("Green Tea", "🍵"),
        // …are 🧋 iced, cold or frozen, as are frappés and boba.
        ("Iced Vanilla Latte", "🧋"),
        ("Cold Brew", "🧋"),
        ("Iced Coffee", "🧋"),
        ("Iced Mocha", "🧋"),
        ("Iced Matcha Latte", "🧋"),
        ("Iced Chai Tea", "🧋"),
        ("Frozen Hot Chocolate", "🧋"),
        ("Caramel Frappe", "🧋"),
        ("Mocha Frappuccino", "🧋"),
        ("Taro Bubble Tea", "🧋"),
        // Other cold drinks.
        ("Iced Tea", "🥤"),
        ("Iced Green Tea", "🥤"),
        ("Strawberry Banana Smoothie", "🥤"),
        ("Lemonade", "🍋"),
        ("Frozen Lemonade", "🍋"),
        // A cold word among the trimmings, or on food, changes nothing.
        ("Latte with Cold Foam", "☕️"),
        ("Iced Lemon Pound Cake", "🍰"),
    ])
    func servesDrinksHotOrCold(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test(arguments: [
        // Breakfast bowls and cereal.
        ("Blackberry Yogurt Bowl", "🥣"),
        ("Açaí Bowl", "🥣"),
        ("Smoothie Bowl", "🥣"),
        ("Oatmeal Bowl", "🥣"),
        ("Apple Cinnamon Oatmeal", "🥣"),
        ("Honey Nut Cheerios", "🥣"),
        ("Frosted Flakes", "🥣"),
        ("Cinnamon Toast Crunch", "🥣"),
        ("Bowl of Cereal", "🥣"),
        // Every other bowl.
        ("Salmon Poke Bowl", "🍣"),
        ("Chicken Burrito Bowl", "🌯"),
        ("Fruit Bowl", "🍇"),
        ("Teriyaki Chicken Bowl", "🍚"),
        ("Grain Bowl", "🍚"),
        ("Rice Bowl", "🍚"),
    ])
    func tellsBowlsApart(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test(arguments: [
        ("Steak Frites", "🥩"), // not "tea"
        ("Piece of Cake", "🍰"), // not "pie"
        ("Chipotle Chicken", "🍗"), // not "chip"
        ("Eggplant Parm", "🍆"), // not "egg"
        ("Donut", "🍩"), // not "nut"
    ])
    func matchesWholeWords(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test(arguments: [
        ("Chocolate Chip Cookies", "🍪"),
        ("Mini Sandwiches", "🥪"),
        ("Mixed Berries", "🫐"),
        ("Peaches", "🍑"),
        ("Tomatoes", "🍅"),
    ])
    func allowsPlurals(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test(arguments: [
        ("ICED TEA", "🥤"),
        ("Café Latte", "☕️"),
        ("Crème Brûlée", "🍮"),
        ("Açaí", "🫐"),
        ("  hot   chocolate ", "☕️"),
    ])
    func ignoresCaseAccentsAndSpacing(item: String, emoji: String) {
        #expect(CafeItemArt.emoji(for: item) == emoji)
    }

    @Test func drawsEveryRealShapedItem() throws {
        // The items of `StoreStatement.sample` and the charges fixture.
        let expected = [
            "Roasted Turkey & Cheddar Panini with Pesto": "🥪",
            "Oatmeal Raisin Cookie": "🍪",
            "Kettle Chips": "🥔",
            "Everything Bagel with Butter": "🥯",
            "Coconut Water": "🥥",
            "Pumpkin Bread": "🍞",
            "Ham & Cheddar Melt": "🥪",
            "Apple Cinnamon Oatmeal": "🥣",
            "Cold Brew": "🧋",
            "Orange Juice": "🧃",
            "Vanilla Steamer": "☕️",
            "Blackberry Yogurt Bowl": "🥣",
            "Lemonade": "🍋",
            "Matcha Latte": "🍵",
            "Turkey & Swiss Panini": "🥪",
            "Grilled Chicken Caesar Wrap with Parmesan": "🌯",
            "Chai Latte": "🍵",
            "Bagel with Cream Cheese": "🥯",
            "Iced Latte": "🧋",
            "Soft Pretzel": "🥨",
            "Iced Tea": "🥤",
            "Banana Bread Slice": "🍞",
            "Breakfast Burrito": "🌯",
            "Greek Yogurt Parfait": "🥣",
            "Hot Chocolate": "☕️",
            "Fresh Fruit Cup": "🍇",
            "Chocolate Chip Cookie": "🍪",
            "Spinach, Feta & Egg White Breakfast Wrap": "🌯",
        ]
        for (item, emoji) in expected {
            #expect(CafeItemArt.emoji(for: item) == emoji, "\(item)")
        }

        let statement = try StoreService.parse(Fixture.data("synthetic-store-charges.json"), fetchedAt: .now)
        let cafeItems = (statement.charges + StoreStatement.sample.charges)
            .filter { CafeWrapped.isCafe($0.storeName) }
            .map(\.detail)
        #expect(Set(cafeItems).isSubset(of: expected.keys))
    }

    @Test func fallsBackToAPlate() {
        #expect(CafeItemArt.emoji(for: "Mystery Special") == "🍽️")
        #expect(CafeItemArt.emoji(for: "Nobles Crew Sweatshirt") == "🍽️")
        #expect(CafeItemArt.emoji(for: "") == "🍽️")
    }
}
