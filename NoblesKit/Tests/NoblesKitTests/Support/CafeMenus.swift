import Foundation
@testable import NoblesKit

/// Nobles' real cafe menus (printed 2026-11-10), with every item named as charges write it.
enum CafeMenus {
    static let gleason = "Cafe at Gleason Hall"
    static let cafe2000 = "Cafe 2000"

    /// Cafe at Gleason Hall's items and prices. Open Monday to Friday, 8:30 to 10:45 AM.
    static let gleasonPrices: [String: String] = [
        "Blueberry Crumb Muffin": "3.00", "Quaker Oatmeal Bowl": "2.50", "Chocolate Croissant": "3.00",
        "Cinnamon Sugar Donut": "3.00", "Chobani Yogurt Drink": "3.00", "Cup of Grapes": "2.50",
        "Cup of Pineapple": "3.00", "Cup of Strawberries": "3.00", "Chobani Yogurt-5.3 Oz.": "2.50",
        "Gatorade Whey Protein Bar": "4.50", "Cheeto Puffs": "3.00", "Cheetos Crunchy Hot": "3.00",
        "Dried Mango": "2.00", "Lays Chips": "2.50", "Popcorners": "3.00", "Rice Krispie Treat": "2.00",
        "Candy": "2.00", "Cheezit": "2.00", "Chex mix": "2.00", "Ms. Vicki Chips": "3.00", "Doritos": "3.00",
        "Goldfish": "2.00", "Haribo Gummy Bears": "2.50", "Oreo Cookies": "2.00", "Smartfood Popcorn": "3.00",
        "Stacey's Pita Chips": "2.00", "Sunchips": "2.00", "Chicken Cup of Noodles": "3.00", "Body Armor": "3.00",
        "Boxed Water": "2.25", "Core Power": "5.00", "Fairlife Milk": "2.50", "IZZE Drink": "3.00",
        "Naked Juice": "3.75", "Polar Seltzer": "2.00", "Powerade": "2.50", "Nestle Hot Cocoa": "2.50",
        "Strawberry-Banana Smoothie": "3.00", "Jumbo Chocolate Chip Cookie": "2.00", "Fudge Brownie": "2.00",
    ]

    /// Cafe 2000's items and prices. Open 2:30 to 6 PM, from 1:30 on Wednesdays.
    static let cafe2000Prices: [String: String] = [
        "Whole Fruit": "1.25", "Chobani Yogurt": "2.50", "Cup of Grapes": "2.00", "Cup of Pineapple": "2.50",
        "Fruit Cup": "2.50", "Nobles Yogurt Cup": "3.00", "Apple Caramel Bar": "3.00", "Chocolate Croissant": "3.00",
        "Chocolate Cup Cake": "2.50", "Cinnamon Sugar Donut": "2.50", "Fudge Brownie": "2.00",
        "Gluten Free Chocolate Torte": "3.00", "Jumbo Chocolate Chip Cookie": "2.50", "Large Croissant": "3.00",
        "Lemon Square": "3.00", "Molten Chocolate Cake": "3.00", "Red Velvet Cup Cake": "2.25",
        "Tira Misu Cake": "3.00", "Candy Bar": "2.00", "Cheese Puffs": "3.00", "Cheetos Crunchy Hot": "3.00",
        "Cheezit": "2.00", "Chex mix": "2.00", "Doritos": "2.00", "Dried Mango": "2.00", "Goldfish": "2.00",
        "Gummy Bears": "2.50", "Jumbo Cheese Puffs": "2.00", "King Soft Baked Pretzel": "3.00", "Lays Chips": "2.50",
        "Ms. Vicki Chips": "2.50", "Oh Snap Pickle": "2.00", "Oreo Cookies": "2.00", "Pirate Booty": "2.00",
        "Popcorners": "3.00", "Smartfood Popcorn": "2.25", "Stacey's Pita Chips": "2.00",
        "Sunchips- Original & Garden Salsa": "2.00", "Apple Cider": "2.50", "Arnold Palmer 1/2&1/2": "2.50",
        "Body Armor": "3.00", "Boxed Water": "2.25", "Core Power": "5.00", "Fairlife Milk": "2.50",
        "IZZE Drink": "3.00", "Naked Juice": "3.75", "Nestle Hot Chocolate": "2.50", "Polar Seltzer": "2.00",
        "Power Water-Kiwi Strawberry": "3.00", "Powerade": "2.50", "Swoon Beverage": "2.50",
        "Bacon Mac n Cheese": "5.00", "Chicken Parmesan Sandwich": "6.00", "Chicken Tenders": "6.00",
        "Cup of Noodles": "3.00", "Grilled Cheese Sandwich": "6.00", "Sunbutter & Jelly": "3.00",
        "Gatorade Recovery Protein Bar": "4.00", "Brownie Ice Cream Sundae Cup": "2.50",
        "Chips Galore Ice Cream Sandwich": "2.50", "Oreo Ice Cream Sandwich": "2.50",
        "Strawberry Shortcake Ice Cream Sundae": "2.50", "Cheese Pizza": "6.00", "Pepperoni Pizza": "6.00",
    ]

    /// Real items seen in purchases but not on the printed menus, with no price to check.
    static let offMenu: [String: String] = ["Egg, Bacon, American on Croissant": gleason, "RX Bar": gleason]

    /// Every item name across both menus and `offMenu`.
    static var allItems: Set<String> {
        Set(gleasonPrices.keys).union(cafe2000Prices.keys).union(offMenu.keys)
    }

    /// Whether `charge` is a real item of its cafe, at that cafe's price per unit when it has one.
    static func isOnMenu(_ charge: StoreCharge) -> Bool {
        let prices = charge.storeName == gleason ? gleasonPrices : charge.storeName == cafe2000 ? cafe2000Prices : [:]
        guard let price = prices[charge.detail] else { return offMenu[charge.detail] == charge.storeName }
        return Decimal(string: price).map { $0 * Decimal(charge.quantity) == charge.amount } ?? false
    }

    /// Whether `charge` was made while its cafe was open, in school time.
    static func isDuringHours(_ charge: StoreCharge) -> Bool {
        let parts = Calendar.school.dateComponents([.hour, .minute], from: charge.madeAt)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let day = LocalDate(charge.madeAt)
        guard !day.isWeekend else { return false }
        switch charge.storeName {
        case gleason: return (8 * 60 + 30...10 * 60 + 45).contains(minute)
        case cafe2000: return ((day.weekday == 4 ? 13 : 14) * 60 + 30...18 * 60).contains(minute)
        default: return false
        }
    }
}
