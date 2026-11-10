import Foundation

/// A part of the day, in school time: the one holding someone's busiest hour headlines their
/// recap (`CafeWrapped.timeOfDay`).
public enum CafeTimeOfDay: String, CaseIterable, Sendable {
    /// Before 11:00.
    case morning
    /// 11:00–13:59.
    case midday
    /// 14:00–16:59.
    case afternoon
    /// 17:00 on.
    case evening

    public var displayName: String {
        switch self {
        case .morning: "Morning"
        case .midday: "Lunch"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }

    /// A headline for someone whose busiest hour falls in this part of the day.
    public var title: String {
        switch self {
        case .morning: "Morning person"
        case .midday: "Lunchtime snacker"
        case .afternoon: "Afternoon snacker"
        case .evening: "Evening snacker"
        }
    }

    public var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .midday: "sun.max.fill"
        case .afternoon: "cloud.sun.fill"
        case .evening: "moon.stars.fill"
        }
    }

    /// The hours of the day (0–23) in this bucket.
    public var hours: ClosedRange<Int> {
        switch self {
        case .morning: 0...10
        case .midday: 11...13
        case .afternoon: 14...16
        case .evening: 17...23
        }
    }
}

/// A label for how someone uses the cafes, chosen by the first rule that matches:
/// loyalist (favorite ≥ 25% of units and ≥ 5 units), nightOwl (≥ 40% of purchases at/after 17:00),
/// earlyBird (≥ 50% before 10:00), regular (purchase days ≥ 50% of the period's school days so far),
/// explorer (≥ 12 distinct items and distinct/purchases ≥ 0.4), else dropIn.
public enum CafePersona: String, CaseIterable, Sendable {
    case loyalist, nightOwl, earlyBird, regular, explorer, dropIn

    public var title: String {
        switch self {
        case .loyalist: "The Superfan"
        case .nightOwl: "The Late Snacker"
        case .earlyBird: "The Early Bird"
        case .regular: "The Regular"
        case .explorer: "The Explorer"
        case .dropIn: "The Drop-In"
        }
    }

    public var tagline: String {
        switch self {
        case .loyalist: "You found a favorite and kept buying it."
        case .nightOwl: "Your cafe runs happen late in the day."
        case .earlyBird: "You get to the cafe early."
        case .regular: "You're at the cafe most days."
        case .explorer: "You like trying new things."
        case .dropIn: "You stop by now and then."
        }
    }

    public var emoji: String {
        switch self {
        case .loyalist: "🫶"
        case .nightOwl: "🦉"
        case .earlyBird: "🌅"
        case .regular: "⭐️"
        case .explorer: "🧭"
        case .dropIn: "👋"
        }
    }

    /// What the persona rules look at.
    struct Evidence {
        /// Units of the favorite item.
        var favoriteUnits: Int
        var units: Int
        var purchases: Int
        /// Purchases at or after 17:00.
        var eveningPurchases: Int
        /// Purchases before 10:00.
        var earlyPurchases: Int
        var purchaseDays: Int
        /// School days in the period so far.
        var schoolDays: Int
        var distinctItems: Int
    }

    /// The first persona, in declaration order, whose rule `evidence` meets.
    init(_ evidence: Evidence) {
        self = Self.allCases.first { $0.fits(evidence) } ?? .dropIn
    }

    /// This persona's rule, in integer arithmetic so boundaries are exact.
    private func fits(_ evidence: Evidence) -> Bool {
        switch self {
        case .loyalist:
            evidence.favoriteUnits >= 5 && evidence.favoriteUnits * 4 >= evidence.units
        case .nightOwl:
            evidence.purchases > 0 && evidence.eveningPurchases * 5 >= evidence.purchases * 2
        case .earlyBird:
            evidence.purchases > 0 && evidence.earlyPurchases * 2 >= evidence.purchases
        case .regular:
            evidence.schoolDays > 0 && evidence.purchaseDays * 2 >= evidence.schoolDays
        case .explorer:
            evidence.distinctItems >= 12 && evidence.distinctItems * 5 >= evidence.purchases * 2
        case .dropIn:
            true
        }
    }
}
