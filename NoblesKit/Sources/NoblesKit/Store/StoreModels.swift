import Foundation

/// One purchase charged to a student's school account (a cafe "chit", an athletic-store item, …).
public struct StoreCharge: Hashable, Identifiable, Sendable {
    /// The source's `charge_id`.
    public var id: Int
    /// e.g. "Cafe at Gleason Hall", "Athletic Store". Matches a `StoreTotal.storeName`.
    public var storeName: String
    /// The source's `trans_type`, e.g. "Chit"; `nil` when it doesn't say.
    public var transactionType: String?
    /// The item bought, e.g. "Iced Latte".
    public var detail: String
    public var quantity: Int
    /// The charge amount before tax.
    public var amount: Decimal
    public var tax: Decimal
    /// When the purchase was made. Read its day and hour in school time (`Calendar.school`).
    public var madeAt: Date
    /// The day it posted to the account, or `nil` while still pending.
    public var postedOn: LocalDate?

    public init(
        id: Int,
        storeName: String,
        transactionType: String? = nil,
        detail: String,
        quantity: Int = 1,
        amount: Decimal,
        tax: Decimal = 0,
        madeAt: Date,
        postedOn: LocalDate? = nil
    ) {
        self.id = id
        self.storeName = storeName
        self.transactionType = transactionType
        self.detail = detail
        self.quantity = quantity
        self.amount = amount
        self.tax = tax
        self.madeAt = madeAt
        self.postedOn = postedOn
    }

    /// Amount plus tax.
    public var total: Decimal { amount + tax }

    /// Still awaiting posting to the account.
    public var isPending: Bool { postedOn == nil }
}

/// A store's running total for the period the statement covers.
public struct StoreTotal: Hashable, Sendable {
    public var storeName: String
    public var amount: Decimal
    public var tax: Decimal
    public var total: Decimal

    public init(storeName: String, amount: Decimal, tax: Decimal = 0, total: Decimal) {
        self.storeName = storeName
        self.amount = amount
        self.tax = tax
        self.total = total
    }
}

/// A student's account spending: every charge, each store's running total, and the grand total,
/// as of `fetchedAt`. Built from one `get_charges.php` response.
public struct StoreStatement: Hashable, Sendable {
    /// Every charge, newest first.
    public var charges: [StoreCharge]
    /// One running total per store.
    public var totalsByStore: [StoreTotal]
    /// Across every store.
    public var grandTotal: Decimal
    /// When this was fetched: now for a fresh response, or when a cached copy was saved.
    public var fetchedAt: Date

    public init(charges: [StoreCharge], totalsByStore: [StoreTotal], grandTotal: Decimal, fetchedAt: Date) {
        self.charges = charges.sorted { $0.madeAt > $1.madeAt }
        self.totalsByStore = totalsByStore
        self.grandTotal = grandTotal
        self.fetchedAt = fetchedAt
    }

    /// Distinct store names, in the order the source lists their totals, for pickers.
    public var stores: [String] { totalsByStore.map(\.storeName) }

    /// The charges for `stores` (matched case-insensitively), newest first. Empty `stores` means all.
    public func charges(in stores: [String]) -> [StoreCharge] {
        guard !stores.isEmpty else { return charges }
        let keys = Set(stores.map { $0.matchKey })
        return charges.filter { keys.contains($0.storeName.matchKey) }
    }

    /// The spending total across `stores` (matched case-insensitively). Empty `stores` means all,
    /// which returns `grandTotal`.
    public func total(in stores: [String]) -> Decimal {
        guard !stores.isEmpty else { return grandTotal }
        let keys = Set(stores.map { $0.matchKey })
        return totalsByStore
            .filter { keys.contains($0.storeName.matchKey) }
            .reduce(0) { $0 + $1.total }
    }

    /// The most recent charge in `stores`, if any.
    public func latestCharge(in stores: [String] = []) -> StoreCharge? {
        charges(in: stores).first
    }
}

/// How current a shown statement is, so the widget and app can badge it.
public enum StoreStatus: Sendable, Hashable {
    /// Fetched fresh this refresh.
    case live
    /// Showing a cached copy because the network was unreachable.
    case offline
    /// The saved sign-in was rejected or has expired; any data shown is cached. The user re-connects
    /// in the app.
    case signedOut
    /// No Nobles account has been connected yet.
    case disconnected
}

/// A signed-in session for the Nobles school-store pages. Captured by the app when the user logs
/// in through Veracross, and read by the widget to fetch that user's own spending.
///
/// It holds only the server session cookie and the signed-in person's id — never a password. The
/// cookie is short-lived, so the widget falls back to cached data and prompts a re-connect in the
/// app once the server rejects it.
public struct StoreSession: Codable, Hashable, Sendable {
    /// The `Cookie:` header value for `nobilis.nobles.edu`, e.g. "PHPSESSID=…".
    public var cookie: String
    /// The signed-in person's `child_id`/`person_id`, which keys the charges endpoint.
    public var personID: String
    /// The signed-in person's name, for display; `nil` when it couldn't be read.
    public var personName: String?
    /// When the session was captured.
    public var connectedAt: Date

    public init(cookie: String, personID: String, personName: String? = nil, connectedAt: Date = .now) {
        self.cookie = cookie
        self.personID = personID
        self.personName = personName
        self.connectedAt = connectedAt
    }
}

/// Stores the school-store `StoreSession` in the app group, so the app writes it at sign-in and the
/// widget reads it to refresh. A `Sendable` value, so widget timeline providers use it directly.
public struct StoreSessionStore: Sendable {
    static let key = "store.session.v1"

    private let suiteName: String?

    /// `suiteName` `nil` uses standard defaults.
    public init(suiteName: String? = AppGroup.identifier) {
        self.suiteName = suiteName
    }

    /// Resolved per call: `UserDefaults` isn't `Sendable`, and this keeps the store trivially so.
    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The saved session, or `nil` if none is stored or it can't be read.
    public func load() -> StoreSession? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(StoreSession.self, from: data)
    }

    /// Saves `session`, replacing any existing one.
    public func save(_ session: StoreSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Forgets the saved session (on explicit disconnect).
    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

// MARK: - Widget configuration

/// Settings for a spending widget design.
public struct StoreConfiguration: Codable, Hashable, Sendable {
    /// Stores to include, each matching a `StoreCharge.storeName` ignoring case. Empty means all.
    public var stores: [String]
    /// What the single prominent figure shows (the Lock Screen and small sizes).
    public var highlight: StoreHighlight
    /// A spending cap for the included stores, drawn as a progress ring/bar; `nil` shows none. The
    /// limit is entered in the app, since the charges endpoint doesn't carry it.
    public var limit: Decimal?
    /// Show the recent-charges list where there's room (medium and large).
    public var showsRecentCharges: Bool

    public init(
        stores: [String] = [],
        highlight: StoreHighlight = .totalSpent,
        limit: Decimal? = nil,
        showsRecentCharges: Bool = true
    ) {
        self.stores = stores
        self.highlight = highlight
        self.limit = limit
        self.showsRecentCharges = showsRecentCharges
    }

    /// Missing fields take their defaults, so settings saved by other versions still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = StoreConfiguration()
        stores = container.decode(.stores, or: defaults.stores)
        highlight = container.decode(.highlight, or: defaults.highlight)
        limit = container.lenient(Decimal.self, forKey: .limit)
        showsRecentCharges = container.decode(.showsRecentCharges, or: defaults.showsRecentCharges)
    }
}

/// The figure a spending widget leads with.
public enum StoreHighlight: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Total spent across the included stores.
    case totalSpent
    /// Left before the limit (`limit` − spent); falls back to total spent when no limit is set.
    case remaining
    /// The amount of the most recent charge.
    case latestCharge

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .totalSpent: "Total spent"
        case .remaining: "Remaining"
        case .latestCharge: "Latest charge"
        }
    }
}
