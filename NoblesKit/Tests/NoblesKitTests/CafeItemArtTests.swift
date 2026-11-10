import Foundation
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

    @Test func drawsEveryMenuItem() {
        let expected = [
            // Cafe at Gleason Hall
            "Blueberry Crumb Muffin": "🧁", "Quaker Oatmeal Bowl": "🥣", "Chocolate Croissant": "🥐",
            "Cinnamon Sugar Donut": "🍩", "Chobani Yogurt Drink": "🥤", "Cup of Grapes": "🍇", "Cup of Pineapple": "🍍",
            "Cup of Strawberries": "🍓", "Chobani Yogurt-5.3 Oz.": "🥣", "Gatorade Whey Protein Bar": "🍫",
            "Cheeto Puffs": "🧀", "Cheetos Crunchy Hot": "🌶️", "Dried Mango": "🥭", "Lays Chips": "🥔",
            "Popcorners": "🍿", "Rice Krispie Treat": "🍪", "Candy": "🍬", "Cheezit": "🧀", "Chex mix": "🥨",
            "Ms. Vicki Chips": "🥔", "Doritos": "🌽", "Goldfish": "🐠", "Haribo Gummy Bears": "🍬", "Oreo Cookies": "🍪",
            "Smartfood Popcorn": "🍿", "Stacey's Pita Chips": "🫓", "Sunchips": "🥔", "Chicken Cup of Noodles": "🍜",
            "Body Armor": "🥤", "Boxed Water": "💧", "Core Power": "🥛", "Fairlife Milk": "🥛", "IZZE Drink": "🥤",
            "Naked Juice": "🧃", "Polar Seltzer": "💧", "Powerade": "🥤", "Nestle Hot Cocoa": "☕️",
            "Strawberry-Banana Smoothie": "🥤", "Jumbo Chocolate Chip Cookie": "🍪", "Fudge Brownie": "🍫",
            // Cafe 2000, beyond the items both cafes sell
            "Whole Fruit": "🍎", "Chobani Yogurt": "🥣", "Fruit Cup": "🍇", "Nobles Yogurt Cup": "🥣",
            "Apple Caramel Bar": "🍎", "Chocolate Cup Cake": "🧁", "Gluten Free Chocolate Torte": "🍰",
            "Large Croissant": "🥐", "Lemon Square": "🍋", "Molten Chocolate Cake": "🍰", "Red Velvet Cup Cake": "🧁",
            "Tira Misu Cake": "🍰", "Candy Bar": "🍫", "Cheese Puffs": "🧀", "Gummy Bears": "🍬",
            "Jumbo Cheese Puffs": "🧀", "King Soft Baked Pretzel": "🥨", "Oh Snap Pickle": "🥒", "Pirate Booty": "🍿",
            "Sunchips- Original & Garden Salsa": "🥔", "Apple Cider": "🧃", "Arnold Palmer 1/2&1/2": "🍋",
            "Nestle Hot Chocolate": "☕️", "Power Water-Kiwi Strawberry": "🥤", "Swoon Beverage": "🥤",
            "Bacon Mac n Cheese": "🧀", "Chicken Parmesan Sandwich": "🥪", "Chicken Tenders": "🍗",
            "Cup of Noodles": "🍜", "Grilled Cheese Sandwich": "🥪", "Sunbutter & Jelly": "🥪",
            "Gatorade Recovery Protein Bar": "🍫", "Brownie Ice Cream Sundae Cup": "🍨",
            "Chips Galore Ice Cream Sandwich": "🍦", "Oreo Ice Cream Sandwich": "🍦",
            "Strawberry Shortcake Ice Cream Sundae": "🍨", "Cheese Pizza": "🍕", "Pepperoni Pizza": "🍕",
            // Off the printed menus
            "Egg, Bacon, American on Croissant": "🥐", "RX Bar": "🍫",
        ]
        #expect(Set(expected.keys) == CafeMenus.allItems)
        for (item, emoji) in expected {
            #expect(CafeItemArt.emoji(for: item) == emoji, "\(item)")
        }
    }

    @Test func readsFlavorsAfterADish() {
        #expect(CafeItemArt.emoji(for: "Power Water-Kiwi Strawberry") == "🥤") // not 🍓
        #expect(CafeItemArt.emoji(for: "Chobani Yogurt Strawberry") == "🥣")
        #expect(CafeItemArt.emoji(for: "Strawberry-Banana Smoothie") == "🥤")
        #expect(CafeItemArt.emoji(for: "Cup of Strawberries") == "🍓") // nothing but the fruit
        #expect(CafeItemArt.emoji(for: "Dried Mango") == "🥭")
    }

    @Test func drawsTheChargesFixture() throws {
        let expected = [
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
        let statement = try StoreService.parse(Fixture.data("synthetic-store-charges.json"), fetchedAt: .now)
        let cafeItems = statement.charges.filter { CafeWrapped.isCafe($0.storeName) }.map(\.detail)
        #expect(Set(cafeItems) == Set(expected.keys))
        for (item, emoji) in expected {
            #expect(CafeItemArt.emoji(for: item) == emoji, "\(item)")
        }
    }

    // MARK: Product photos

    @Test func photographsEveryBrandedMenuItem() {
        let expected = [
            "Quaker Oatmeal Bowl": "quaker-oatmeal",
            "Chobani Yogurt-5.3 Oz.": "chobani-yogurt", "Chobani Yogurt": "chobani-yogurt",
            "Gatorade Whey Protein Bar": "gatorade-bar", "Gatorade Recovery Protein Bar": "gatorade-bar",
            "Cheeto Puffs": "cheetos-puffs", "Cheetos Crunchy Hot": "cheetos-crunchy-hot", "Lays Chips": "lays",
            "Popcorners": "popcorners", "Rice Krispie Treat": "rice-krispies-treat", "Cheezit": "cheez-it",
            "Chex mix": "chex-mix", "Ms. Vicki Chips": "miss-vickies", "Doritos": "doritos", "Goldfish": "goldfish",
            "Haribo Gummy Bears": "haribo", "Oreo Cookies": "oreo", "Oreo Ice Cream Sandwich": "oreo-ice-cream-sandwich",
            "Smartfood Popcorn": "smartfood", "Stacey's Pita Chips": "stacys", "Sunchips": "sunchips",
            "Sunchips- Original & Garden Salsa": "sunchips", "Chicken Cup of Noodles": "cup-noodles",
            "Cup of Noodles": "cup-noodles", "Body Armor": "bodyarmor", "Boxed Water": "boxed-water",
            "Core Power": "core-power", "Fairlife Milk": "fairlife", "IZZE Drink": "izze", "Naked Juice": "naked",
            "Polar Seltzer": "polar", "Powerade": "powerade", "Nestle Hot Cocoa": "nestle-cocoa",
            "Nestle Hot Chocolate": "nestle-cocoa", "Oh Snap Pickle": "oh-snap",
            "Swoon Beverage": "swoon", "Arnold Palmer 1/2&1/2": "arnold-palmer", "RX Bar": "rxbar",
        ]
        #expect(Set(expected.keys).isSubset(of: CafeMenus.allItems))
        for item in CafeMenus.allItems {
            #expect(CafeItemArt.productImage(for: item) == expected[item].map { "product-\($0)" }, "\(item)")
        }
    }

    @Test(arguments: [
        ("Lay's Classic Potato Chips", "product-lays"),
        ("Miss Vickie's Sea Salt", "product-miss-vickies"),
        ("Stacy's Pita Chips", "product-stacys"),
        ("Cheez-It", "product-cheez-it"),
        ("BODYARMOR", "product-bodyarmor"),
        ("Nestlé Hot Cocoa", "product-nestle-cocoa"),
    ])
    func matchesBrandSpellings(item: String, image: String) {
        #expect(CafeItemArt.productImage(for: item) == image)
    }

    @Test func leavesHouseItemsWithoutAPhoto() {
        for item in ["Jumbo Chocolate Chip Cookie", "Cheese Puffs", "Gummy Bears", "Power Water-Kiwi Strawberry",
                     "Chocolate Cup Cake", "Lemon Square", "Gatorade", "Cheetos", "Layer Cake", "Bodyguard",
                     "Chobani Yogurt Drink", "Chobani Drink", "Pirate Booty", "Chips Galore Ice Cream Sandwich", ""] {
            #expect(CafeItemArt.productImage(for: item) == nil, "\(item)")
        }
    }

    @Test func fallsBackToAPlate() {
        #expect(CafeItemArt.emoji(for: "Mystery Special") == "🍽️")
        #expect(CafeItemArt.emoji(for: "Nobles Crew Sweatshirt") == "🍽️")
        #expect(CafeItemArt.emoji(for: "") == "🍽️")
    }
}
