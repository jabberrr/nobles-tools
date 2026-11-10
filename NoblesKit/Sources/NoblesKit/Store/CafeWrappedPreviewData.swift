import Foundation

extension StoreStatement {
    /// A made-up, deterministic semester of cafe charges (plus a few athletic-store ones, which
    /// Wrapped must ignore) for Cafe Wrapped previews and testing without an account. Same output
    /// on every platform and run (seeded integer RNG; no `Double` printing; money from strings).
    ///
    /// The student buys on the semester's school days (weekdays outside Nobles' 2026–27 breaks)
    /// through `through`: mostly at Cafe at Gleason Hall before class, at morning break, at lunch
    /// and after school, and some evenings at Cafe 2000. They skip a day or two most weeks, but not
    /// from the 25th to the 34th school day: a ten-day streak that holds the semester's biggest day.
    public static func wrappedSample(semester: DateSpan, through: LocalDate, fetchedAt: Date) -> StoreStatement {
        var sample = WrappedSample(semester: semester, through: through)
        let charges = sample.charges()
        let totalsByStore = Dictionary(grouping: charges, by: \.storeName)
            .map { name, charges in
                StoreTotal(
                    storeName: name,
                    amount: charges.reduce(0) { $0 + $1.amount },
                    tax: charges.reduce(0) { $0 + $1.tax },
                    total: charges.reduce(0) { $0 + $1.total }
                )
            }
            .sorted { $0.storeName < $1.storeName }
        let grandTotal = totalsByStore.reduce(0) { $0 + $1.total }
        return StoreStatement(charges: charges, totalsByStore: totalsByStore, grandTotal: grandTotal, fetchedAt: fetchedAt)
    }
}

extension CafeWrapped {
    /// The recap of `StoreStatement.wrappedSample` for the whole Fall 2026 semester of
    /// `SchoolCalendar.nobles2026_27`: a Regular whose favorite is the Iced Vanilla Latte.
    public static let sample: CafeWrapped = {
        let calendar = SchoolCalendar.nobles2026_27
        let fall = CafeWrapped.semester(in: calendar, on: LocalDate(year: 2026, month: 9, day: 8))!
        let end = fall.span.end
        let statement = StoreStatement.wrappedSample(semester: fall.span, through: end, fetchedAt: end.at(hour: 23))
        return CafeWrapped(statement: statement, semester: fall, calendar: calendar, asOf: end)!
    }()
}

// MARK: - Generator

/// Builds the charges of `StoreStatement.wrappedSample`.
private struct WrappedSample {
    /// School-day indices of the streak, with no skipped day; the big day falls inside it.
    static let streak = 24..<34
    static let bigDay = 26
    /// The newest charge's id; older ones count down from it, as in the real feed.
    static let newestID = 452_317

    private var random = SplitMix64(seed: 732)
    private var menus = Slot.all.map { Deck($0.menu) }
    private var addOns = Deck(Slot.addOns)
    /// The semester's school days through the sample's last day, in order.
    private let schoolDays: [LocalDate]
    private let lastDay: LocalDate

    init(semester: DateSpan, through: LocalDate) {
        lastDay = min(semester.end, through)
        let breaks = SchoolCalendar.nobles2026_27.breaks
        schoolDays = sequence(first: semester.start) { $0.adding(days: 1) }
            .prefix { $0 <= semester.end }
            .filter { day in !day.isWeekend && !breaks.contains { $0.span.contains(day) } }
    }

    /// Every charge through the last day, oldest first, with ids falling with age. The whole
    /// semester is dealt either way, so a sample cut short is the start of the full one.
    mutating func charges() -> [StoreCharge] {
        let skipped = skippedDays()
        var charges: [StoreCharge] = []
        for (index, day) in schoolDays.enumerated() {
            if index == Self.bigDay {
                charges += Self.bigDayOrders.map { charge($0.item, quantity: $0.quantity, at: $0.store, on: day, minute: $0.minute) }
            } else if !skipped.contains(index) {
                charges += purchases(on: day)
            }
            for order in Self.athleticOrders where order.dayIndex == index {
                charges.append(charge(order.item, at: Store.athletic, on: day, minute: order.minute, tax: order.tax))
            }
        }
        let end = lastDay.adding(days: 1).startOfDay()
        charges = charges.filter { $0.madeAt < end }.sorted { $0.madeAt < $1.madeAt }
        for index in charges.indices {
            charges[index].id = Self.newestID - (charges.count - 1 - index)
        }
        return charges
    }

    /// School-day indices with no cafe visit: one or two a week, likeliest on a Monday or Friday,
    /// none in the streak, and the school days either side of it.
    private mutating func skippedDays() -> Set<Int> {
        var skipped: Set = [Self.streak.lowerBound - 1, Self.streak.upperBound]
        let weeks = Dictionary(grouping: schoolDays.indices) { schoolDays[$0].adding(days: 1 - schoolDays[$0].weekday) }
        for sunday in weeks.keys.sorted() {
            let week = weeks[sunday] ?? []
            guard !week.contains(where: { skipped.contains($0) }) else { continue }
            var open = week.filter { !Self.streak.contains($0) }
            for _ in 0..<(random.percent(30) ? 2 : 1) where !open.isEmpty {
                let index = random.pick(open.map { (value: $0, weight: Self.skipWeight(schoolDays[$0])) })
                skipped.insert(index)
                open.removeAll { $0 == index }
            }
        }
        return skipped
    }

    private static func skipWeight(_ day: LocalDate) -> Int {
        switch day.weekday {
        case 2, 6: 3 // Monday, Friday
        case 4: 2 // Wednesday
        default: 1
        }
    }

    /// A school day's purchases: each slot visited by chance, and the morning break if none is.
    private mutating func purchases(on day: LocalDate) -> [StoreCharge] {
        var charges: [StoreCharge] = []
        for (index, slot) in Slot.all.enumerated() where random.percent(slot.chance[day.weekday - 2]) {
            charges += visit(index, on: day)
        }
        return charges.isEmpty ? visit(0, on: day) : charges
    }

    /// The next item from `Slot.all[index]`, sometimes with an add-on a minute later.
    private mutating func visit(_ index: Int, on day: LocalDate) -> [StoreCharge] {
        let slot = Slot.all[index]
        let minute = random.int(in: slot.minutes)
        var items = [menus[index].draw(using: &random)]
        if random.percent(30) {
            items.append(addOns.draw(using: &random))
        }
        return items.enumerated().map { offset, item in
            charge(item, quantity: pairs(item), at: slot.store, on: day, minute: minute + offset)
        }
    }

    /// Cheap things sometimes come in twos.
    private mutating func pairs(_ item: SampleItem) -> Int {
        item.price < 2.5 && random.percent(15) ? 2 : 1
    }

    private func charge(
        _ item: SampleItem, quantity: Int = 1, at store: String, on day: LocalDate, minute: Int, tax: Decimal = 0
    ) -> StoreCharge {
        StoreCharge(
            id: 0,
            storeName: store,
            transactionType: "Chit",
            detail: item.name,
            quantity: quantity,
            amount: item.price * Decimal(quantity),
            tax: tax,
            madeAt: day.at(hour: minute / 60, minute: minute % 60),
            postedOn: day == lastDay ? nil : day
        )
    }

    // MARK: Scripted days

    /// The big day: something at every stop.
    private static let bigDayOrders: [(minute: Int, store: String, item: SampleItem, quantity: Int)] = [
        (clock(7, 52), Store.gleason, .icedVanillaLatte, 1),
        (clock(10, 24), Store.gleason, .everythingBagel, 1),
        (clock(12, 31), Store.gleason, .chickenPestoPanini, 1),
        (clock(12, 32), Store.gleason, .chocolateChipCookie, 2),
        (clock(14, 38), Store.gleason, .matchaLatte, 1),
        (clock(20, 12), Store.cafe2000, .hotChocolate, 1),
    ]

    /// Athletic-store charges, which Wrapped must leave out.
    private static let athleticOrders: [(dayIndex: Int, minute: Int, item: SampleItem, tax: Decimal)] = [
        (3, clock(15, 40), SampleItem("Nobles Water Bottle", "22.00"), Decimal(string: "1.38") ?? 0),
        (16, clock(16, 5), SampleItem("Team Warm-Up Jacket", "58.00"), 0),
        (41, clock(15, 50), SampleItem("Nobles Baseball Cap", "30.00"), 0),
        (62, clock(16, 20), SampleItem("Nobles Crew Sweatshirt", "56.00"), 0),
    ]
}

// MARK: - Menu

private enum Store {
    static let gleason = "Cafe at Gleason Hall"
    static let cafe2000 = "Cafe 2000"
    static let athletic = "Athletic Store"
}

/// Something for sale, at its price.
private struct SampleItem: Sendable {
    let name: String
    let price: Decimal

    init(_ name: String, _ price: String) {
        self.name = name
        self.price = Decimal(string: price) ?? 0
    }

    static let icedVanillaLatte = SampleItem("Iced Vanilla Latte", "4.75")
    static let everythingBagel = SampleItem("Everything Bagel with Cream Cheese", "3.25")
    static let chocolateChipCookie = SampleItem("Chocolate Chip Cookie", "2.25")
    static let turkeyPanini = SampleItem("Turkey & Swiss Panini", "7.50")
    static let matchaLatte = SampleItem("Matcha Latte", "4.75")
    static let chickenPestoPanini = SampleItem("Chicken Pesto Panini", "8.50")
    static let hotChocolate = SampleItem("Hot Chocolate", "2.50")
    static let softPretzel = SampleItem("Soft Pretzel", "3.00")
}

/// Items with how often each turns up.
private typealias Menu = [(item: SampleItem, weight: Int)]

/// A time and place the student might stop by, and what they come for.
private struct Slot: Sendable {
    let store: String
    /// Minutes after midnight, school time.
    let minutes: ClosedRange<Int>
    /// The percent chance of a visit on a school day the student isn't skipping, Monday to Friday.
    let chance: [Int]
    let menu: Menu

    /// Every slot, the morning break first: the student's surest stop.
    static let all: [Slot] = [
        Slot(store: Store.gleason, minutes: clock(10, 10)...clock(10, 40), chance: [85, 92, 85, 92, 80], menu: [
            (.icedVanillaLatte, 8), (.everythingBagel, 8), (.matchaLatte, 2),
            (SampleItem("Chocolate Croissant", "3.50"), 1), (SampleItem("Blueberry Muffin", "3.00"), 1),
            (SampleItem("Greek Yogurt Parfait", "4.25"), 1), (SampleItem("Cold Brew", "3.75"), 1),
        ]),
        Slot(store: Store.gleason, minutes: clock(7, 45)...clock(8, 20), chance: [20, 20, 20, 20, 20], menu: [
            (.icedVanillaLatte, 3), (.everythingBagel, 3), (SampleItem("Orange Juice", "2.75"), 1),
            (SampleItem("Apple Cinnamon Oatmeal", "3.50"), 1), (SampleItem("Breakfast Burrito", "6.50"), 1),
        ]),
        Slot(store: Store.gleason, minutes: clock(12, 10)...clock(12, 55), chance: [60, 75, 65, 75, 55], menu: [
            (.turkeyPanini, 5), (.icedVanillaLatte, 1), (SampleItem("Grilled Chicken Caesar Wrap", "7.25"), 2),
            (SampleItem("Tomato Basil Soup", "4.50"), 2), (SampleItem("Mac & Cheese", "5.75"), 2),
            (SampleItem("Fresh Fruit Cup", "3.75"), 1),
        ]),
        Slot(store: Store.gleason, minutes: clock(14, 5)...clock(15, 10), chance: [30, 40, 30, 40, 25], menu: [
            (.icedVanillaLatte, 2), (.matchaLatte, 2), (.softPretzel, 1),
            (SampleItem("Strawberry Banana Smoothie", "6.25"), 1), (SampleItem("Pumpkin Bread", "2.75"), 1),
        ]),
        Slot(store: Store.cafe2000, minutes: clock(18, 45)...clock(21, 30), chance: [35, 40, 35, 40, 0], menu: [
            (.chocolateChipCookie, 1), (.hotChocolate, 2), (.softPretzel, 1),
            (SampleItem("Mozzarella Sticks", "5.25"), 1), (SampleItem("Pepperoni Pizza Slice", "4.25"), 1),
            (SampleItem("Ice Cream Sandwich", "3.50"), 1), (SampleItem("Cup Noodles", "2.00"), 1),
            (SampleItem("Coconut Water", "3.25"), 1),
        ]),
    ]

    /// Small extras picked up along with the main thing.
    static let addOns: Menu = [
        (.chocolateChipCookie, 3), (SampleItem("Kettle Chips", "1.75"), 1), (SampleItem("Banana", "1.50"), 1),
        (SampleItem("Iced Tea", "2.25"), 1), (SampleItem("Lemonade", "2.50"), 1), (SampleItem("Popcorn", "1.50"), 1),
        (SampleItem("Rice Krispie Treat", "2.00"), 1), (SampleItem("Granola Bar", "1.75"), 1),
    ]
}

/// A menu as a shuffled deck, dealt card by card and reshuffled when empty, so each item turns up
/// about as often as its weight says and the sample's favorites keep their order.
private struct Deck {
    private let menu: Menu
    private var cards: [SampleItem] = []

    init(_ menu: Menu) {
        self.menu = menu
    }

    mutating func draw(using random: inout SplitMix64) -> SampleItem {
        if cards.isEmpty {
            cards = menu.flatMap { Array(repeating: $0.item, count: $0.weight) }
            random.shuffle(&cards)
        }
        return cards.removeLast()
    }
}

/// Minutes after midnight.
private func clock(_ hour: Int, _ minute: Int) -> Int {
    hour * 60 + minute
}

/// SplitMix64: a tiny seeded generator, so the sample is the same on every platform and run.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in `range`.
    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    /// True `percent` times in a hundred.
    mutating func percent(_ percent: Int) -> Bool {
        int(in: 0...99) < percent
    }

    /// One of `options`, each as likely as its weight.
    mutating func pick<Value>(_ options: [(value: Value, weight: Int)]) -> Value {
        var roll = int(in: 0...(options.reduce(0) { $0 + $1.weight } - 1))
        for option in options {
            if roll < option.weight { return option.value }
            roll -= option.weight
        }
        preconditionFailure("pick(_:) needs positive weights")
    }

    /// Shuffles `array` in place (Fisher–Yates).
    mutating func shuffle<Element>(_ array: inout [Element]) {
        for index in array.indices.reversed() where index > 0 {
            array.swapAt(index, int(in: 0...index))
        }
    }
}
