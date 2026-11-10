import Foundation

extension StoreStatement {
    /// A realistic statement for previews and widget placeholders: six weeks of made-up charges at
    /// the three real Nobles stores, grand total $151.75.
    public static var sample: StoreStatement { sample(now: .now) }

    /// The sample statement with charges dated around `now`, so renders don't change day to day.
    /// Cafe charges are real menu items at their real prices, during each cafe's hours, on the
    /// school days before today. Each store's running total is the sum of the charges shown for it.
    /// The newest charge, made this morning and still pending, has the longest name of anything sold
    /// at Gleason, to stress the Lock Screen layouts.
    public static func sample(now: Date) -> StoreStatement {
        let today = LocalDate(now)
        // Today, then the school days before it, newest first.
        let earlier = sequence(first: today.adding(days: -1)) { $0.adding(days: -1) }.lazy.filter { $0.isSampleSchoolDay }
        let days = [today] + earlier.prefix(30)
        var nextID = 318_406
        func charge(_ store: String, _ item: String, _ amount: String,
                    schoolDaysAgo: Int, hour: Int, minute: Int, pending: Bool = false) -> StoreCharge {
            defer { nextID -= 1 }
            let day = days[schoolDaysAgo]
            return StoreCharge(
                id: nextID,
                storeName: store,
                transactionType: "Chit",
                detail: item,
                amount: Decimal(string: amount) ?? 0,
                madeAt: day.at(hour: hour, minute: minute),
                postedOn: pending ? nil : day
            )
        }

        let gleason = "Cafe at Gleason Hall"
        let cafe2000 = "Cafe 2000"
        let athletic = "Athletic Store"
        // Newest first, so ids fall with age as in the real feed.
        let charges = [
            charge(gleason, "Egg, Bacon, American on Croissant", "5.00", schoolDaysAgo: 0, hour: 10, minute: 41, pending: true),
            charge(cafe2000, "Jumbo Chocolate Chip Cookie", "2.50", schoolDaysAgo: 1, hour: 15, minute: 52, pending: true),
            charge(cafe2000, "Doritos", "2.00", schoolDaysAgo: 3, hour: 16, minute: 20),
            charge(gleason, "Body Armor", "3.00", schoolDaysAgo: 4, hour: 10, minute: 12),
            charge(gleason, "Chocolate Croissant", "3.00", schoolDaysAgo: 5, hour: 8, minute: 47),
            charge(cafe2000, "Chicken Tenders", "6.00", schoolDaysAgo: 6, hour: 17, minute: 14),
            charge(gleason, "Strawberry-Banana Smoothie", "3.00", schoolDaysAgo: 8, hour: 10, minute: 33),
            charge(gleason, "Jumbo Chocolate Chip Cookie", "2.00", schoolDaysAgo: 9, hour: 10, minute: 5),
            charge(gleason, "Quaker Oatmeal Bowl", "2.50", schoolDaysAgo: 10, hour: 8, minute: 39),
            charge(athletic, "Nobles Baseball Cap", "30.00", schoolDaysAgo: 12, hour: 15, minute: 48),
            charge(cafe2000, "King Soft Baked Pretzel", "3.00", schoolDaysAgo: 13, hour: 15, minute: 31),
            charge(gleason, "Cup of Strawberries", "3.00", schoolDaysAgo: 14, hour: 10, minute: 27),
            charge(cafe2000, "Body Armor", "3.00", schoolDaysAgo: 15, hour: 16, minute: 2),
            charge(gleason, "Cinnamon Sugar Donut", "3.00", schoolDaysAgo: 17, hour: 9, minute: 58),
            charge(gleason, "Nestle Hot Cocoa", "2.50", schoolDaysAgo: 18, hour: 8, minute: 52),
            charge(cafe2000, "Cheese Pizza", "6.00", schoolDaysAgo: 19, hour: 17, minute: 36),
            charge(gleason, "Chobani Yogurt Drink", "3.00", schoolDaysAgo: 21, hour: 10, minute: 40),
            charge(cafe2000, "Whole Fruit", "1.25", schoolDaysAgo: 22, hour: 14, minute: 58),
            charge(gleason, "Blueberry Crumb Muffin", "3.00", schoolDaysAgo: 24, hour: 10, minute: 16),
            charge(cafe2000, "Oreo Ice Cream Sandwich", "2.50", schoolDaysAgo: 25, hour: 16, minute: 44),
            charge(gleason, "Jumbo Chocolate Chip Cookie", "2.00", schoolDaysAgo: 26, hour: 10, minute: 21),
            charge(athletic, "Nobles Crew Sweatshirt", "56.00", schoolDaysAgo: 27, hour: 16, minute: 10),
            charge(gleason, "Powerade", "2.50", schoolDaysAgo: 28, hour: 9, minute: 12),
            charge(gleason, "Dried Mango", "2.00", schoolDaysAgo: 29, hour: 10, minute: 35),
        ]

        let totalsByStore = Dictionary(grouping: charges, by: \.storeName)
            .map { name, items in
                StoreTotal(
                    storeName: name,
                    amount: items.reduce(0) { $0 + $1.amount },
                    tax: items.reduce(0) { $0 + $1.tax },
                    total: items.reduce(0) { $0 + $1.total }
                )
            }
            .sorted { $0.storeName < $1.storeName }
        let grandTotal = totalsByStore.reduce(0) { $0 + $1.total }
        return StoreStatement(charges: charges, totalsByStore: totalsByStore, grandTotal: grandTotal, fetchedAt: now)
    }
}

extension LocalDate {
    /// Whether the samples may put a purchase on this day: a weekday outside the built-in calendar's
    /// breaks, in any year, so a sample dated around any day still lands on weekdays.
    var isSampleSchoolDay: Bool {
        !isWeekend && !SchoolCalendar.nobles2026_27.breaks.contains { $0.span.contains(self) }
    }
}
