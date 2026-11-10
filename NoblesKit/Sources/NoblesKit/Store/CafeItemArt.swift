import Foundation

/// A food or drink emoji for a cafe item name, standing in for a photo.
public enum CafeItemArt {
    /// Matches whole words (so "tea" doesn't match "steak", "pie" doesn't match "piece"), allowing
    /// plurals, ignoring case/accents; the most specific keyword wins, e.g. "Oatmeal Raisin Cookie"
    /// → 🍪, "Apple Cinnamon Oatmeal" → 🥣, "Hot Chocolate" → ☕️, "Ice Cream Sandwich" → 🍦,
    /// "Coconut Water" → 🥥, "Orange Juice" → 🧃, "Matcha Latte" → 🍵, "Iced Vanilla Latte" → ☕️,
    /// "Everything Bagel with Butter" → 🥯, "Roasted Turkey & Cheddar Panini with Pesto" → 🥪,
    /// "Blackberry Yogurt Bowl" → 🥣, "Kettle Chips" → 🥔, "Pumpkin Bread" → 🍞. Fallback "🍽️".
    ///
    /// The most specific keyword is the dish's head noun: the match that ends last in the name,
    /// before any "with …" trimmings, and on a tie the longer phrase ("Hot Chocolate" over
    /// "Chocolate"). Phrases such as "Matcha Latte" cover the dishes named for something else.
    public static func emoji(for item: String) -> String {
        let words = item.matchKey.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let head = words.prefix { $0 != "with" && $0 != "w" }
        return bestMatch(in: Array(head)) ?? bestMatch(in: words) ?? "🍽️"
    }

    /// The emoji of the keyword ending last in `words`, the longer one on a tie.
    private static func bestMatch(in words: [String]) -> String? {
        var best: (end: Int, length: Int, emoji: String)?
        for keyword in keywords where keyword.words.count <= words.count {
            for start in 0...(words.count - keyword.words.count) {
                let matches = zip(keyword.words, words[start...]).allSatisfy { forms, word in forms.contains(word) }
                let end = start + keyword.words.count
                if matches, best.map({ (end, keyword.words.count) > ($0.end, $0.length) }) ?? true {
                    best = (end, keyword.words.count, keyword.emoji)
                }
            }
        }
        return best?.emoji
    }

    /// A word or phrase that names a food, with the spellings each of its words accepts.
    private struct Keyword: Sendable {
        let words: [Set<String>]
        let emoji: String

        init(_ phrase: String, emoji: String) {
            words = phrase.split(separator: " ").map { Self.forms(of: String($0)) }
            self.emoji = emoji
        }

        /// `word` and its regular plurals: "cookies", "sandwiches", "berries".
        private static func forms(of word: String) -> Set<String> {
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

    /// Lowercase, accent-free keywords by emoji, from drinks to fruit. Their order doesn't decide a
    /// match; the dish's head noun does (see `emoji(for:)`).
    private static let keywords: [Keyword] = {
        let table: [(emoji: String, phrases: [String])] = [
            // Drinks
            ("☕️", ["coffee", "latte", "cappuccino", "espresso", "americano", "macchiato", "mocha", "cortado",
                    "flat white", "brew", "steamer", "cocoa", "hot chocolate"]),
            ("🍵", ["tea", "matcha", "chai", "kombucha", "matcha latte", "chai latte", "tea latte", "london fog"]),
            ("🧋", ["boba", "bubble tea"]),
            ("🥤", ["smoothie", "shake", "milkshake", "frappe", "frappuccino", "soda", "slushie", "gatorade",
                    "iced tea", "root beer"]),
            ("🧃", ["juice", "cider"]),
            ("🥛", ["milk"]),
            ("💧", ["water", "seltzer"]),
            ("🥥", ["coconut", "coconut water"]),
            // Bakery
            ("🍪", ["cookie", "biscotti", "macaron", "macaroon", "shortbread", "snickerdoodle",
                    "chocolate chip", "rice krispie"]),
            ("🧁", ["muffin", "cupcake"]),
            ("🍰", ["cake", "cheesecake", "tiramisu"]),
            ("🥐", ["croissant", "danish", "scone", "pastry", "turnover", "strudel",
                    "cinnamon roll", "cinnamon bun", "sticky bun"]),
            ("🍩", ["donut", "doughnut", "cruller"]),
            ("🥯", ["bagel"]),
            ("🍞", ["bread", "toast", "loaf", "cornbread", "brioche", "english muffin"]),
            ("🥖", ["baguette"]),
            ("🥨", ["pretzel"]),
            ("🧇", ["waffle"]),
            ("🥞", ["pancake", "crepe", "flapjack"]),
            ("🥧", ["pie", "tart", "cobbler", "crisp"]),
            // Breakfast
            ("🥣", ["oatmeal", "oat", "porridge", "granola", "cereal", "yogurt", "yoghurt", "parfait", "bowl"]),
            ("🍳", ["egg", "omelet", "omelette", "frittata", "scramble", "breakfast"]),
            ("🥓", ["bacon", "sausage"]),
            // Sandwiches
            ("🥪", ["sandwich", "panini", "sub", "hoagie", "grinder", "melt", "club", "blt", "grilled cheese"]),
            ("🌯", ["wrap", "burrito", "gyro", "shawarma"]),
            ("🌮", ["taco", "nacho", "enchilada"]),
            ("🫓", ["quesadilla", "flatbread", "pita", "naan"]),
            ("🍔", ["burger", "cheeseburger", "hamburger", "slider"]),
            ("🌭", ["hotdog", "hot dog", "corn dog"]),
            // Hot food
            ("🍕", ["pizza", "calzone", "stromboli"]),
            ("🍲", ["soup", "chowder", "chili", "stew", "bisque"]),
            ("🍜", ["ramen", "noodle", "pho", "udon", "lo mein"]),
            ("🍝", ["pasta", "spaghetti", "penne", "ziti", "lasagna", "ravioli", "tortellini", "alfredo", "meatball"]),
            ("🍚", ["rice", "risotto", "rice bowl"]),
            ("🍛", ["curry", "tikka masala"]),
            ("🍣", ["sushi", "poke"]),
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
            ("🥔", ["potato", "chip", "tot", "tater", "hash brown"]),
            ("🍿", ["popcorn"]),
            ("🥜", ["nut", "peanut", "almond", "cashew", "pistachio", "trail mix"]),
            ("🧀", ["cheese", "cheddar", "mozzarella", "brie", "mac", "macaroni"]),
            ("🍘", ["cracker", "rice cake"]),
            ("🥕", ["carrot", "celery", "veggie"]),
            ("🫛", ["edamame"]),
            ("🌽", ["corn"]),
            ("🍆", ["eggplant"]),
            ("🍅", ["tomato"]),
            // Sweets
            ("🍦", ["gelato", "froyo", "cone", "ice cream", "soft serve", "frozen yogurt", "ice cream sandwich"]),
            ("🍨", ["sundae", "sorbet"]),
            ("🍧", ["italian ice", "shaved ice", "snow cone"]),
            ("🍫", ["chocolate", "brownie", "blondie", "fudge", "granola bar", "protein bar", "candy bar"]),
            ("🍬", ["candy", "caramel", "gummy", "taffy", "jelly bean"]),
            ("🍭", ["lollipop"]),
            ("🍡", ["mochi"]),
            ("🍮", ["pudding", "flan", "custard", "creme brulee"]),
            ("🍯", ["honey"]),
            // Fruit
            ("🍎", ["apple"]),
            ("🍌", ["banana"]),
            ("🍊", ["orange", "clementine", "mandarin", "tangerine"]),
            ("🍋", ["lemon", "lemonade"]),
            ("🍓", ["strawberry"]),
            ("🫐", ["blueberry", "blackberry", "berry", "acai"]),
            ("🍇", ["grape", "raisin", "fruit", "fruit salad"]),
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
        return table.flatMap { entry in entry.phrases.map { Keyword($0, emoji: entry.emoji) } }
    }()
}
