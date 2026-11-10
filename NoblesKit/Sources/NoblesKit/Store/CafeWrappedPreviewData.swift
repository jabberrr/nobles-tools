import Foundation

extension StoreStatement {
    /// A made-up, deterministic semester of cafe charges (plus a few athletic-store ones, which
    /// Wrapped must ignore) for Cafe Wrapped previews and testing without an account. Same output
    /// on every platform and run (seeded integer RNG; no `Double` printing; money from strings).
    ///
    /// Every cafe charge is a real menu item at its real price, made during that cafe's hours on a
    /// school day (a weekday outside Nobles' 2026–27 breaks) through `through`: mornings at Cafe at
    /// Gleason Hall, before class and at the morning break, and afternoons at Cafe 2000, after
    /// school and after practice. The student skips a day or two most weeks, but not from the 25th
    /// to the 34th school day: a ten-day streak that holds the semester's biggest day and its
    /// biggest purchase.
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
    /// `SchoolCalendar.nobles2026_27`: a Regular whose favorite is the Jumbo Chocolate Chip Cookie,
    /// with Body Armor and Doritos next.
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
    private var addOns = Slot.all.map { Deck($0.addOns) }
    /// The semester's school days, in order.
    private let schoolDays: [LocalDate]
    private let lastDay: LocalDate

    init(semester: DateSpan, through: LocalDate) {
        lastDay = min(semester.end, through)
        schoolDays = sequence(first: semester.start) { $0.adding(days: 1) }
            .prefix { $0 <= semester.end }
            .filter(\.isSampleSchoolDay)
    }

    /// Every charge through the last day, oldest first, with ids falling with age. The whole
    /// semester is dealt either way, so a sample cut short is the start of the full one.
    mutating func charges() -> [StoreCharge] {
        let skipped = skippedDays()
        var charges: [StoreCharge] = []
        for (index, day) in schoolDays.enumerated() {
            if index == Self.bigDay {
                charges += Self.bigDayOrders.map { charge($0, on: day) }
            } else if !skipped.contains(index) {
                charges += purchases(on: day)
            }
            charges += Self.extraOrders.filter { $0.dayIndex == index }.map { charge($0.order, on: day) }
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
        let weeks = Dictionary(grouping: schoolDays.indices) { index in
            schoolDays[index].adding(days: 1 - schoolDays[index].weekday)
        }
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
            items.append(addOns[index].draw(using: &random))
        }
        return items.enumerated().map { offset, item in
            let order = Order(minute: minute + offset, store: slot.store, item: item, quantity: pairs(item))
            return charge(order, on: day)
        }
    }

    /// Cheap things sometimes come in twos.
    private mutating func pairs(_ item: SampleItem) -> Int {
        item.price < 2.5 && random.percent(15) ? 2 : 1
    }

    private func charge(_ order: Order, on day: LocalDate) -> StoreCharge {
        StoreCharge(
            id: 0,
            storeName: order.store,
            transactionType: "Chit",
            detail: order.item.name,
            quantity: order.quantity,
            amount: order.item.price * Decimal(order.quantity),
            tax: order.tax,
            madeAt: day.at(hour: order.minute / 60, minute: order.minute % 60),
            postedOn: day == lastDay ? nil : day
        )
    }

    // MARK: Scripted days

    /// The big day: something at every stop.
    private static let bigDayOrders: [Order] = [
        Order(minute: clock(8, 41), store: Gleason.name, item: Gleason.hotCocoa),
        Order(minute: clock(8, 42), store: Gleason.name, item: Gleason.chocolateCroissant),
        Order(minute: clock(10, 16), store: Gleason.name, item: Gleason.cookie, quantity: 2),
        Order(minute: clock(10, 17), store: Gleason.name, item: Gleason.bodyArmor),
        Order(minute: clock(15, 8), store: Cafe2000.name, item: Cafe2000.chickenTenders),
        Order(minute: clock(15, 9), store: Cafe2000.name, item: Cafe2000.doritos),
        Order(minute: clock(17, 24), store: Cafe2000.name, item: Cafe2000.pepperoniPizza),
        Order(minute: clock(17, 25), store: Cafe2000.name, item: Cafe2000.powerade),
    ]

    /// Orders on top of a day's usual purchases: pizza for two, the priciest cafe charge, and
    /// athletic-store charges, which Wrapped must leave out.
    private static let extraOrders: [(dayIndex: Int, order: Order)] = [
        (3, Order(minute: clock(15, 40), store: athletic, item: SampleItem("Nobles Water Bottle", "22.00"), tax: "1.38")),
        (16, Order(minute: clock(16, 5), store: athletic, item: SampleItem("Team Warm-Up Jacket", "58.00"))),
        (31, Order(minute: clock(17, 18), store: Cafe2000.name, item: Cafe2000.cheesePizza, quantity: 2)),
        (41, Order(minute: clock(15, 50), store: athletic, item: SampleItem("Nobles Baseball Cap", "30.00"))),
        (62, Order(minute: clock(16, 20), store: athletic, item: SampleItem("Nobles Crew Sweatshirt", "56.00"))),
    ]

    private static let athletic = "Athletic Store"
}

/// Something bought at a time and place.
private struct Order: Sendable {
    /// Minutes after midnight, school time.
    let minute: Int
    let store: String
    let item: SampleItem
    let quantity: Int
    let tax: Decimal

    init(minute: Int, store: String, item: SampleItem, quantity: Int = 1, tax: String = "0") {
        self.minute = minute
        self.store = store
        self.item = item
        self.quantity = quantity
        self.tax = Decimal(string: tax) ?? 0
    }
}

// MARK: - Menus

/// Something for sale, at its price.
private struct SampleItem: Sendable {
    let name: String
    let price: Decimal

    init(_ name: String, _ price: String) {
        self.name = name
        self.price = Decimal(string: price) ?? 0
    }
}

/// Cafe at Gleason Hall (Monday to Friday, 8:30 to 10:45 AM): the items the sample buys at both
/// cafes or in more than one place, at its prices.
private enum Gleason {
    static let name = "Cafe at Gleason Hall"
    static let cookie = SampleItem("Jumbo Chocolate Chip Cookie", "2.00")
    static let bodyArmor = SampleItem("Body Armor", "3.00")
    static let doritos = SampleItem("Doritos", "3.00")
    static let chocolateCroissant = SampleItem("Chocolate Croissant", "3.00")
    static let cinnamonSugarDonut = SampleItem("Cinnamon Sugar Donut", "3.00")
    static let muffin = SampleItem("Blueberry Crumb Muffin", "3.00")
    static let hotCocoa = SampleItem("Nestle Hot Cocoa", "2.50")
    static let powerade = SampleItem("Powerade", "2.50")
}

/// Cafe 2000 (2:30 to 6 PM, from 1:30 on Wednesdays): the items the sample buys at both cafes or
/// in more than one place, at its prices.
private enum Cafe2000 {
    static let name = "Cafe 2000"
    static let cookie = SampleItem("Jumbo Chocolate Chip Cookie", "2.50")
    static let bodyArmor = SampleItem("Body Armor", "3.00")
    static let doritos = SampleItem("Doritos", "2.00")
    static let chickenTenders = SampleItem("Chicken Tenders", "6.00")
    static let cheesePizza = SampleItem("Cheese Pizza", "6.00")
    static let pepperoniPizza = SampleItem("Pepperoni Pizza", "6.00")
    static let powerade = SampleItem("Powerade", "2.50")
}

/// Items with how often each turns up.
private typealias Menu = [(item: SampleItem, weight: Int)]

/// A time and place the student might stop by, and what they come for.
private struct Slot: Sendable {
    let store: String
    /// Minutes after midnight, school time, inside the cafe's hours with a minute to spare for an
    /// add-on.
    let minutes: ClosedRange<Int>
    /// The percent chance of a visit on a school day the student isn't skipping, Monday to Friday.
    let chance: [Int]
    let menu: Menu
    /// Small extras sometimes picked up with the main thing.
    let addOns: Menu

    /// Every slot, the morning break first: the student's surest stop.
    static let all: [Slot] = [
        Slot(store: Gleason.name, minutes: clock(10, 0)...clock(10, 43), chance: [80, 88, 80, 88, 75], menu: [
            (Gleason.cookie, 5), (Gleason.bodyArmor, 4), (Gleason.doritos, 3),
            (SampleItem("Strawberry-Banana Smoothie", "3.00"), 2),
            (Gleason.chocolateCroissant, 1), (Gleason.cinnamonSugarDonut, 1), (Gleason.muffin, 1),
            (SampleItem("Cup of Strawberries", "3.00"), 1), (SampleItem("Chobani Yogurt Drink", "3.00"), 1),
            (SampleItem("Rice Krispie Treat", "2.00"), 1), (SampleItem("Goldfish", "2.00"), 1),
            (SampleItem("Fudge Brownie", "2.00"), 1), (SampleItem("Cheeto Puffs", "3.00"), 1),
            (SampleItem("Popcorners", "3.00"), 1),
        ], addOns: gleasonAddOns),
        Slot(store: Gleason.name, minutes: clock(8, 30)...clock(9, 20), chance: [25, 25, 25, 25, 25], menu: [
            (SampleItem("Quaker Oatmeal Bowl", "2.50"), 2), (Gleason.hotCocoa, 2), (Gleason.chocolateCroissant, 2),
            (Gleason.muffin, 1), (Gleason.cinnamonSugarDonut, 1), (SampleItem("Fairlife Milk", "2.50"), 1),
            (SampleItem("Naked Juice", "3.75"), 1), (SampleItem("Core Power", "5.00"), 1),
        ], addOns: gleasonAddOns),
        Slot(store: Cafe2000.name, minutes: clock(14, 45)...clock(16, 30), chance: [55, 60, 60, 60, 50], menu: [
            (Cafe2000.cookie, 3), (Cafe2000.chickenTenders, 3), (Cafe2000.doritos, 3), (Cafe2000.bodyArmor, 3),
            (SampleItem("King Soft Baked Pretzel", "3.00"), 1), (Cafe2000.cheesePizza, 1), (Cafe2000.pepperoniPizza, 1),
            (SampleItem("Cup of Noodles", "3.00"), 1), (SampleItem("Bacon Mac n Cheese", "5.00"), 1),
            (SampleItem("Oreo Ice Cream Sandwich", "2.50"), 1), (SampleItem("Chocolate Cup Cake", "2.50"), 1),
            (SampleItem("Apple Cider", "2.50"), 1), (SampleItem("Sunbutter & Jelly", "3.00"), 1),
            (SampleItem("Molten Chocolate Cake", "3.00"), 1),
        ], addOns: cafe2000AddOns),
        Slot(store: Cafe2000.name, minutes: clock(17, 0)...clock(17, 55), chance: [20, 20, 20, 20, 0], menu: [
            (Cafe2000.chickenTenders, 2), (Cafe2000.powerade, 1), (SampleItem("Gatorade Recovery Protein Bar", "4.00"), 1),
            (SampleItem("Grilled Cheese Sandwich", "6.00"), 1), (Cafe2000.pepperoniPizza, 1),
            (SampleItem("Arnold Palmer 1/2&1/2", "2.50"), 1),
        ], addOns: cafe2000AddOns),
    ]

    static let gleasonAddOns: Menu = [
        (Gleason.cookie, 3), (Gleason.bodyArmor, 1), (Gleason.powerade, 1), (SampleItem("Polar Seltzer", "2.00"), 1),
        (SampleItem("Boxed Water", "2.25"), 1), (SampleItem("Dried Mango", "2.00"), 1), (SampleItem("Cheezit", "2.00"), 1),
        (SampleItem("Haribo Gummy Bears", "2.50"), 1),
    ]

    static let cafe2000AddOns: Menu = [
        (Cafe2000.cookie, 2), (Cafe2000.bodyArmor, 1), (Cafe2000.doritos, 1), (SampleItem("Whole Fruit", "1.25"), 1),
        (SampleItem("Oh Snap Pickle", "2.00"), 1), (SampleItem("Pirate Booty", "2.00"), 1),
        (SampleItem("Gummy Bears", "2.50"), 1),
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
