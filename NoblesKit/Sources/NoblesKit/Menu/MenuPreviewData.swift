import Foundation

extension DailyMenu {
    /// A realistic menu in Nobles' station layout (dishes from real October 2026 menus), for
    /// widget placeholders and previews. Nobles publishes no breakfast; that sample is illustrative.
    public static func sample(meal: Meal = .lunch, date: LocalDate = .today()) -> DailyMenu {
        let stations: [(title: String, dishes: [String])] = switch meal {
        case .breakfast: [
            ("Hot Breakfast", ["Scrambled Eggs", "Applewood Smoked Bacon", "Home Fries"]),
            ("Griddle", ["Buttermilk Pancakes, Maple Syrup"]),
            ("Bakery", ["Blueberry Muffins"]),
        ]
        case .lunch: [
            ("Soup Station", ["Cream of Broccoli & Cheddar Soup"]),
            ("Hot Entree", ["Revved Up Macaroni & Cheese"]),
            ("Vegan Entree", ["Tomato, Kale, Red Bean & Pasta Toss, Chive Oil"]),
            ("Sides", ["Warm Bread Sticks", "Roasted Green Beans with Shallots"]),
            ("Weekly Composed Salad", ["Mini Caprese Salad, Arugula & Balsamic Glaze"]),
            ("Dessert", ["Tres Leche Cake"]),
        ]
        case .dinner: [
            ("Hot Entree", ["Cordon Bleu Style Chicken", "Herb Veloute"]),
            ("Sides", ["Whole Grain & Rice Blend", "Steamed Yellow Squash, Tarragon"]),
            ("Vegan Option", ["Whole Grain Stuffed Peppers"]),
            ("Dessert", ["Apple Crisp, Vanilla Ice Cream"]),
        ]
        }
        var id = 0
        let sections = stations.map { station in
            MenuSection(title: station.title, items: station.dishes.map { name in
                id += 1
                return MenuItem(id: id, name: name)
            })
        }
        return DailyMenu(date: date, meal: meal, sections: sections)
    }
}
