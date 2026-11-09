import Foundation

extension StoreStatement {
    /// A realistic statement for previews and widget placeholders: a term's worth of cafe and
    /// athletic-store charges across the three real Nobles stores, grand total $136.75.
    public static var sample: StoreStatement { sample(now: .now) }

    /// The sample statement with charges dated around `now`, so renders don't change day to day.
    /// Each store's running total is the sum of the charges shown for it.
    public static func sample(now: Date) -> StoreStatement {
        let today = LocalDate(now)
        var nextID = 660_000
        func charge(_ store: String, _ item: String, _ amount: String,
                    daysAgo: Int, hour: Int = 13, minute: Int = 30, pending: Bool = false) -> StoreCharge {
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

        var charges = [
            charge("Athletic Store", "UA MENS", "55.00", daysAgo: 34, hour: 21, minute: 3),
            charge("Cafe 2000", "RX Bar", "3.50", daysAgo: 23, hour: 21, minute: 31),
            charge("Cafe 2000", "Powerade", "2.50", daysAgo: 29, hour: 21, minute: 11),
            charge("Cafe 2000", "Chips Galore Ice Cream Sandwich", "2.50", daysAgo: 30, hour: 20, minute: 33),
            charge("Cafe 2000", "Whole Fruit", "1.25", daysAgo: 31, hour: 20, minute: 50),
            charge("Cafe at Gleason Hall", "Dried Mango", "2.00", daysAgo: 32),
        ]
        // Cafe at Gleason Hall breakfast — ten $4 croissants and ten $3 snacks, for a $72 total.
        for (index, daysAgo) in [0, 4, 7, 8, 11, 14, 17, 20, 25, 30].enumerated() {
            charges.append(charge("Cafe at Gleason Hall", "Egg, Bacon, American on Croissant", "4.00",
                                  daysAgo: daysAgo, minute: 30 + index, pending: daysAgo == 0))
        }
        let snacks = ["Strawberry-Banana Smoothie", "Chocolate Chocolate Chip Muffin",
                      "Blueberry Crumb Muffin", "Cup of Strawberries"]
        for (index, daysAgo) in [1, 5, 9, 12, 15, 18, 21, 26, 28, 33].enumerated() {
            charges.append(charge("Cafe at Gleason Hall", snacks[index % snacks.count], "3.00",
                                  daysAgo: daysAgo, hour: 14, minute: index, pending: daysAgo == 1))
        }

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
