import Foundation

/// Pictures for cafe items: a food or drink emoji for any item, and a product photo for branded ones.
public enum CafeItemArt {
    /// Matches whole words (so "tea" doesn't match "steak", "pie" doesn't match "piece"), allowing
    /// plurals, ignoring case/accents/apostrophes; the most specific keyword wins, e.g. "Oatmeal
    /// Raisin Cookie" → 🍪, "Apple Cinnamon Oatmeal" → 🥣, "Hot Chocolate" → ☕️, "Ice Cream
    /// Sandwich" → 🍦, "Coconut Water" → 🥥, "Orange Juice" → 🧃, "Matcha Latte" → 🍵, "Iced Vanilla
    /// Latte" → 🧋, "Everything Bagel with Butter" → 🥯, "Roasted Turkey & Cheddar Panini with Pesto"
    /// → 🥪, "Blackberry Yogurt Bowl" → 🥣, "Poke Bowl" → 🍣, "Kettle Chips" → 🥔, "Pumpkin Bread" →
    /// 🍞, "Power Water-Kiwi Strawberry" → 🥤. Fallback "🍽️".
    ///
    /// The most specific keyword is the dish's head noun: the match that ends last in the name,
    /// before any "with …" trimmings and any fruit named after the dish as its flavor, and on a tie
    /// the longer phrase ("Hot Chocolate" over "Chocolate"). Phrases such as "Matcha Latte" cover the
    /// dishes named for something else.
    ///
    /// Drinks are ☕️ (coffee, cocoa) or 🍵 (tea, matcha, chai) when hot. After "iced", "cold" or
    /// "frozen", or as a frappé or boba, coffee, matcha and chai drinks are 🧋; other cold drinks
    /// (iced tea, smoothies, soda) are 🥤, and lemonade 🍋. A bowl is 🍚 unless it's a breakfast
    /// bowl (yogurt, açaí, smoothie, oatmeal, cereal, granola: 🥣), a poke bowl (🍣) or a burrito
    /// bowl (🌯).
    public static func emoji(for item: String) -> String {
        let words = words(in: item)
        let head = Array(words.prefix { $0 != "with" && $0 != "w" })
        var dish = head
        while let last = dish.last, flavorWords.contains(last) {
            dish.removeLast()
        }
        return emoji(in: dish) ?? emoji(in: head) ?? emoji(in: words) ?? "🍽️"
    }

    /// The asset name of a branded item's product photo, "product-<slug>", e.g. "Body Armor" →
    /// "product-bodyarmor"; `nil` for everything else. Names match by whole words like `emoji(for:)`,
    /// the most specific first: "Oreo Ice Cream Sandwich" → "product-oreo-ice-cream-sandwich", "Oreo
    /// Cookies" → "product-oreo".
    public static func productImage(for item: String) -> String? {
        bestMatch(among: products, in: words(in: item))?.value.map { "product-\($0)" }
    }

    /// The words of `name` for matching: lowercase and accent-free, apostrophes dropped ("Stacey's"
    /// → "staceys"), split at anything else that isn't a letter or digit.
    private static func words(in name: String) -> [String] {
        name.matchKey
            .filter { $0 != "'" && $0 != "’" }
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Words that turn a hot drink named after them cold: "Iced Vanilla Latte", "Cold Brew".
    private static let coldWords: Set = ["iced", "cold", "frozen"]

    /// The emoji of the keyword that best matches `words`, in its cold form after a cold word.
    private static func emoji(in words: [String]) -> String? {
        guard let match = bestMatch(among: keywords, in: words) else { return nil }
        let isCold = words[..<match.start].contains(where: coldWords.contains)
        return isCold ? match.value.cold ?? match.value.emoji : match.value.emoji
    }

    /// The entry whose phrase ends last in `words`, the longer phrase on a tie and the earlier entry
    /// on a full tie, with the index of the word where its match starts.
    private static func bestMatch<Value>(among entries: [Entry<Value>], in words: [String]) -> (value: Value, start: Int)? {
        var best: (value: Value, start: Int, end: Int)?
        for entry in entries where entry.phrase.count <= words.count {
            for start in 0...(words.count - entry.phrase.count) where entry.matches(words, at: start) {
                let end = start + entry.phrase.count
                if best.map({ (end, end - start) > ($0.end, $0.end - $0.start) }) ?? true {
                    best = (entry.value, start, end)
                }
            }
        }
        return best.map { ($0.value, $0.start) }
    }

    /// A word or phrase to look for, with the spellings each of its words accepts, and what it means.
    private struct Entry<Value: Sendable>: Sendable {
        let phrase: [Set<String>]
        let value: Value

        init(_ phrase: String, _ value: Value) {
            self.phrase = phrase.split(separator: " ").map { Self.forms(of: String($0)) }
            self.value = value
        }

        /// Whether the phrase is at `start` in `words`.
        func matches(_ words: [String], at start: Int) -> Bool {
            zip(phrase, words[start...]).allSatisfy { forms, word in forms.contains(word) }
        }

        /// `word` and its regular plurals: "cookies", "sandwiches", "berries".
        static func forms(of word: String) -> Set<String> {
            var forms: Set = [word, word + "s"]
            if let last = word.last, "sxzho".contains(last) {
                forms.insert(word + "es")
            }
            if word.hasSuffix("y") {
                forms.insert(String(word.dropLast()) + "ies")
            }
            return forms
        }
    }

    /// An emoji, and the one it turns into after a cold word, for hot drinks.
    private struct Art: Sendable {
        let emoji: String
        let cold: String?
    }

    /// Fruit, by emoji. Fruit named after a dish is its flavor: "Power Water-Kiwi Strawberry".
    private static let fruit: [(emoji: String, phrases: [String])] = [
        ("🍎", ["apple"]),
        ("🍌", ["banana"]),
        ("🍊", ["orange", "clementine", "mandarin", "tangerine"]),
        ("🍋", ["lemon", "lemonade"]),
        ("🍓", ["strawberry"]),
        ("🫐", ["blueberry", "blackberry", "berry", "acai"]),
        ("🍇", ["grape", "raisin", "fruit", "fruit salad", "fruit bowl"]),
        ("🍉", ["watermelon"]),
        ("🍈", ["melon", "cantaloupe", "honeydew"]),
        ("🍍", ["pineapple"]),
        ("🥭", ["mango"]),
        ("🍑", ["peach"]),
        ("🍐", ["pear"]),
        ("🍒", ["cherry"]),
        ("🥝", ["kiwi"]),
        ("🥑", ["avocado", "guacamole", "avocado toast"]),
        ("🎃", ["pumpkin"]),
    ]

    /// The spellings of the one-word fruit keywords.
    private static let flavorWords: Set<String> = Set(
        fruit.flatMap(\.phrases).filter { !$0.contains(" ") }.flatMap(Entry<Art>.forms(of:))
    )

    /// Lowercase, accent-free keywords. Their order doesn't decide a match; the dish's head noun
    /// does (see `emoji(for:)`).
    private static let keywords: [Entry<Art>] = {
        // Hot drinks, with their emoji after a cold word.
        let hotDrinks: [(emoji: String, cold: String, phrases: [String])] = [
            ("☕️", "🧋", ["coffee", "latte", "cappuccino", "espresso", "americano", "macchiato", "mocha", "cortado",
                          "flat white", "brew", "steamer", "cocoa", "hot chocolate"]),
            ("🍵", "🧋", ["matcha", "chai", "matcha latte", "chai latte", "chai tea", "tea latte", "london fog"]),
            ("🍵", "🥤", ["tea"]),
        ]
        let table: [(emoji: String, phrases: [String])] = [
            // Cold drinks
            ("🧋", ["boba", "bubble tea", "frappe", "frappuccino"]),
            ("🥤", ["smoothie", "shake", "milkshake", "soda", "slushie", "kombucha", "root beer", "drink", "beverage",
                    "gatorade", "powerade", "body armor", "bodyarmor", "power water", "swoon"]),
            ("🧃", ["juice", "cider"]),
            ("🥛", ["milk", "core power", "corepower"]),
            ("💧", ["water", "seltzer"]),
            ("🥥", ["coconut", "coconut water"]),
            ("🍋", ["arnold palmer"]),
            // Bakery
            ("🍪", ["cookie", "biscotti", "macaron", "macaroon", "shortbread", "snickerdoodle",
                    "chocolate chip", "rice krispie"]),
            ("🧁", ["muffin", "cupcake", "cup cake"]),
            ("🍰", ["cake", "cheesecake", "tiramisu", "tira misu", "torte"]),
            ("🥐", ["croissant", "danish", "scone", "pastry", "turnover", "strudel",
                    "cinnamon roll", "cinnamon bun", "sticky bun"]),
            ("🍩", ["donut", "doughnut", "cruller"]),
            ("🥯", ["bagel"]),
            ("🍞", ["bread", "toast", "loaf", "cornbread", "brioche", "english muffin"]),
            ("🥖", ["baguette"]),
            ("🥨", ["pretzel", "chex", "chex mix", "snack mix"]),
            ("🧇", ["waffle"]),
            ("🥞", ["pancake", "crepe", "flapjack"]),
            ("🥧", ["pie", "tart", "cobbler", "crisp"]),
            // Breakfast
            ("🥣", ["oatmeal", "oat", "porridge", "granola", "muesli", "cereal", "cheerio", "corn flake",
                    "frosted flake", "raisin bran", "froot loop", "lucky charm", "cinnamon toast crunch",
                    "yogurt", "yoghurt", "parfait", "yogurt bowl", "yoghurt bowl", "acai bowl", "smoothie bowl",
                    "oatmeal bowl", "cereal bowl", "granola bowl"]),
            ("🍳", ["egg", "omelet", "omelette", "frittata", "scramble", "breakfast"]),
            ("🥓", ["bacon", "sausage"]),
            // Sandwiches
            ("🥪", ["sandwich", "panini", "sub", "hoagie", "grinder", "melt", "club", "blt", "grilled cheese",
                    "sunbutter", "butter jelly", "butter and jelly", "pbj"]),
            ("🌯", ["wrap", "burrito", "gyro", "shawarma", "burrito bowl"]),
            ("🌮", ["taco", "nacho", "enchilada"]),
            ("🫓", ["quesadilla", "flatbread", "pita", "naan", "pita chip"]),
            ("🍔", ["burger", "cheeseburger", "hamburger", "slider"]),
            ("🌭", ["hotdog", "hot dog", "corn dog"]),
            // Hot food
            ("🍕", ["pizza", "calzone", "stromboli"]),
            ("🍲", ["soup", "chowder", "chili", "stew", "bisque"]),
            ("🍜", ["ramen", "noodle", "pho", "udon", "lo mein"]),
            ("🍝", ["pasta", "spaghetti", "penne", "ziti", "lasagna", "ravioli", "tortellini", "alfredo", "meatball"]),
            ("🍚", ["rice", "risotto", "bowl"]),
            ("🍛", ["curry", "tikka masala"]),
            ("🍣", ["sushi", "poke", "poke bowl"]),
            ("🥟", ["dumpling", "potsticker", "gyoza", "empanada", "samosa", "egg roll", "spring roll"]),
            ("🥗", ["salad", "caesar", "slaw", "coleslaw"]),
            ("🍗", ["chicken", "wing", "drumstick", "tender", "nugget"]),
            ("🍖", ["turkey", "ham", "pork", "rib"]),
            ("🥩", ["steak", "beef", "brisket"]),
            ("🐟", ["fish", "salmon", "tuna", "cod"]),
            ("🍤", ["shrimp", "tempura"]),
            ("🍟", ["fries"]),
            ("🧆", ["falafel", "hummus"]),
            // Snacks
            ("🥔", ["potato", "chip", "tot", "tater", "hash brown", "sunchip", "sun chip"]),
            ("🌽", ["corn", "dorito", "tortilla chip", "corn chip"]),
            ("🍿", ["popcorn", "popcorner", "pirate booty"]),
            ("🌶️", ["crunchy hot", "flamin hot", "hot cheeto"]),
            ("🥜", ["nut", "peanut", "almond", "cashew", "pistachio", "trail mix"]),
            ("🧀", ["cheese", "cheddar", "mozzarella", "brie", "mac", "macaroni", "cheeto", "cheezit", "cheez it"]),
            ("🍘", ["cracker", "rice cake"]),
            ("🐠", ["goldfish"]),
            ("🥒", ["pickle"]),
            ("🥕", ["carrot", "celery", "veggie"]),
            ("🫛", ["edamame"]),
            ("🍆", ["eggplant"]),
            ("🍅", ["tomato"]),
            // Sweets
            ("🍦", ["gelato", "froyo", "cone", "ice cream", "soft serve", "frozen yogurt", "ice cream sandwich"]),
            ("🍨", ["sundae", "sorbet"]),
            ("🍧", ["italian ice", "shaved ice", "snow cone"]),
            ("🍫", ["chocolate", "brownie", "blondie", "fudge", "granola bar", "protein bar", "candy bar",
                    "rx bar", "rxbar"]),
            ("🍬", ["candy", "caramel", "gummy", "taffy", "jelly bean"]),
            ("🍭", ["lollipop"]),
            ("🍡", ["mochi"]),
            ("🍮", ["pudding", "flan", "custard", "creme brulee"]),
            ("🍯", ["honey"]),
            // Fruit as a dish
            ("🍎", ["whole fruit", "apple caramel"]),
        ]
        return hotDrinks.flatMap { drink in drink.phrases.map { Entry($0, Art(emoji: drink.emoji, cold: drink.cold)) } }
            + (table + fruit).flatMap { entry in entry.phrases.map { Entry($0, Art(emoji: entry.emoji, cold: nil)) } }
    }()

    /// Branded items with a product photo: the asset's slug, then the names that mean it. A `nil`
    /// slug marks a product with no good photo, so a looser name can't lend it the wrong one.
    private static let products: [Entry<String?>] = {
        let table: [(slug: String?, names: [String])] = [
            ("quaker-oatmeal", ["quaker"]),
            (nil, ["chobani yogurt drink", "chobani drink"]),
            ("chobani-yogurt", ["chobani"]),
            ("gatorade-bar", ["gatorade whey protein bar", "gatorade recovery protein bar", "gatorade protein bar"]),
            ("cheetos-puffs", ["cheeto puff"]),
            ("cheetos-crunchy-hot", ["cheeto crunchy"]),
            ("lays", ["lay"]),
            ("popcorners", ["popcorner"]),
            ("rice-krispies-treat", ["rice krispie"]),
            ("cheez-it", ["cheezit", "cheez it"]),
            ("chex-mix", ["chex"]),
            ("miss-vickies", ["vicki", "vickie"]),
            ("doritos", ["dorito"]),
            ("goldfish", ["goldfish"]),
            ("haribo", ["haribo"]),
            ("oreo", ["oreo"]),
            ("oreo-ice-cream-sandwich", ["oreo ice cream sandwich"]),
            ("smartfood", ["smartfood"]),
            ("stacys", ["stacey", "stacy"]),
            ("sunchips", ["sunchip", "sun chip"]),
            ("cup-noodles", ["cup of noodle", "cup noodle"]),
            ("bodyarmor", ["body armor", "bodyarmor"]),
            ("boxed-water", ["boxed water"]),
            ("core-power", ["core power", "corepower"]),
            ("fairlife", ["fairlife"]),
            ("izze", ["izze"]),
            ("naked", ["naked"]),
            ("polar", ["polar"]),
            ("powerade", ["powerade"]),
            ("nestle-cocoa", ["nestle"]),
            ("oh-snap", ["oh snap"]),
            ("swoon", ["swoon"]),
            ("arnold-palmer", ["arnold palmer"]),
            ("rxbar", ["rx bar", "rxbar"]),
        ]
        return table.flatMap { product in product.names.map { Entry($0, product.slug) } }
    }()
}
