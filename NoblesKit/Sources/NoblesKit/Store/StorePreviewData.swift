import Foundation

extension StoreStatement {
    /// A realistic statement for previews and widget placeholders: six weeks of made-up cafe and
    /// athletic-store charges across the three real Nobles stores, grand total $158.25.
    public static var sample: StoreStatement { sample(now: .now) }

    /// The sample statement with charges dated around `now`, so renders don't change day to day.
    /// Each store's running total is the sum of the charges shown for it. The newest charge, made
    /// today and still pending, has a long name to stress the Lock Screen layouts.
    public static func sample(now: Date) -> StoreStatement {
        let today = LocalDate(now)
        var nextID = 318_406
        func charge(_ store: String, _ item: String, _ amount: String,
                    daysAgo: Int, hour: Int, minute: Int, pending: Bool = false) -> StoreCharge {
            defer { nextID -= 1 }
            let day = today.adding(days: -daysAgo)
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

        // Newest first, so ids fall with age as in the real feed.
        let charges = [
            charge("Cafe at Gleason Hall", "Roasted Turkey & Cheddar Panini with Pesto", "7.25",
                   daysAgo: 0, hour: 10, minute: 48, pending: true),
            charge("Cafe 2000", "Oatmeal Raisin Cookie", "2.25", daysAgo: 1, hour: 19, minute: 27, pending: true),
            charge("Cafe 2000", "Kettle Chips", "1.50", daysAgo: 4, hour: 20, minute: 13),
            charge("Cafe at Gleason Hall", "Everything Bagel with Butter", "2.25", daysAgo: 5, hour: 10, minute: 48),
            charge("Cafe 2000", "Coconut Water", "3.00", daysAgo: 6, hour: 21, minute: 22),
            charge("Cafe at Gleason Hall", "Pumpkin Bread", "2.50", daysAgo: 7, hour: 13, minute: 51),
            charge("Cafe at Gleason Hall", "Ham & Cheddar Melt", "6.25", daysAgo: 13, hour: 13, minute: 7),
            charge("Cafe at Gleason Hall", "Apple Cinnamon Oatmeal", "3.00", daysAgo: 14, hour: 13, minute: 35),
            charge("Cafe at Gleason Hall", "Everything Bagel with Butter", "2.25", daysAgo: 15, hour: 13, minute: 24),
            charge("Athletic Store", "Nobles Baseball Cap", "30.00", daysAgo: 18, hour: 16, minute: 18),
            charge("Cafe at Gleason Hall", "Cold Brew", "3.75", daysAgo: 19, hour: 10, minute: 22),
            charge("Cafe 2000", "Oatmeal Raisin Cookie", "2.25", daysAgo: 20, hour: 21, minute: 6),
            charge("Cafe at Gleason Hall", "Orange Juice", "2.25", daysAgo: 21, hour: 9, minute: 48),
            charge("Cafe at Gleason Hall", "Vanilla Steamer", "2.75", daysAgo: 26, hour: 10, minute: 50),
            charge("Cafe at Gleason Hall", "Cold Brew", "3.75", daysAgo: 27, hour: 12, minute: 7),
            charge("Cafe at Gleason Hall", "Blackberry Yogurt Bowl", "3.75", daysAgo: 28, hour: 12, minute: 38),
            charge("Cafe at Gleason Hall", "Blackberry Yogurt Bowl", "3.75", daysAgo: 29, hour: 8, minute: 5),
            charge("Cafe 2000", "Lemonade", "2.50", daysAgo: 32, hour: 21, minute: 14),
            charge("Cafe at Gleason Hall", "Apple Cinnamon Oatmeal", "3.00", daysAgo: 33, hour: 9, minute: 46),
            charge("Cafe at Gleason Hall", "Matcha Latte", "4.75", daysAgo: 36, hour: 10, minute: 0),
            charge("Cafe at Gleason Hall", "Matcha Latte", "4.75", daysAgo: 39, hour: 9, minute: 42),
            charge("Athletic Store", "Nobles Crew Sweatshirt", "56.00", daysAgo: 41, hour: 17, minute: 7),
            charge("Cafe at Gleason Hall", "Orange Juice", "2.25", daysAgo: 42, hour: 9, minute: 38),
            charge("Cafe at Gleason Hall", "Pumpkin Bread", "2.50", daysAgo: 43, hour: 14, minute: 50),
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
