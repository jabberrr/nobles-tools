import Testing
@testable import NoblesKit

struct CafeItemArtTests {
    @Test(arguments: [
        // The head noun wins over the flavors and fillings named before it.
        ("Oatmeal Raisin Cookie", "🍪"),
        ("Apple Cinnamon Oatmeal", "🥣"),
        ("Pumpkin Bread", "🍞"),
        ("Kettle Chips", "🥔"),
        ("Blackberry Yogurt Bowl", "🥣"),
        ("Orange Juice", "🧃"),
        ("Iced Vanilla Latte", "☕️"),
        // A phrase beats the word it ends with.
        ("Hot Chocolate", "☕️"),
        ("Ice Cream Sandwich", "🍦"),
        ("Coconut Water", "🥥"),
        ("Matcha Latte", "🍵"),
        ("Iced Tea", "🥤"),
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
            "Cold Brew": "☕️",
            "Orange Juice": "🧃",
            "Vanilla Steamer": "☕️",
            "Blackberry Yogurt Bowl": "🥣",
            "Lemonade": "🍋",
            "Matcha Latte": "🍵",
            "Turkey & Swiss Panini": "🥪",
            "Grilled Chicken Caesar Wrap with Parmesan": "🌯",
            "Chai Latte": "🍵",
            "Bagel with Cream Cheese": "🥯",
            "Iced Latte": "☕️",
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
