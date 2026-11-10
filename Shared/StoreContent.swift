import Foundation
import NoblesKit

/// What a spending design shows, worked out once from its settings, statement and status for every
/// size.
///
/// The statement is `nil` when no Nobles account has been connected, or a lapsed sign-in left
/// nothing cached; the views then show a connect prompt rather than figures. The `note` carries a
/// quiet staleness line ("Updated 4h ago", "Sign in to refresh") when the data is a cached copy.
struct StoreContent {
    enum State {
        /// No account is connected (or an expired one with nothing cached): prompt to sign in.
        case connect
        /// The account is connected but nothing could be loaded, even from the cache.
        case unavailable
        /// Spending to show.
        case spending(Spending)
    }

    let state: State
    /// A quiet note about how current the data is, or `nil` when it's fresh.
    let note: String?
    /// The moment on screen (the timeline entry's date), for relative charge dates.
    let now: Date

    init(statement: StoreStatement?, configuration: StoreConfiguration, status: StoreStatus, now: Date) {
        self.now = now
        if let statement {
            state = .spending(Spending(statement: statement, configuration: configuration, now: now))
            note = Self.note(status: status, fetchedAt: statement.fetchedAt, now: now)
        } else {
            state = status == .disconnected || status == .signedOut ? .connect : .unavailable
            note = nil
        }
    }

    var today: LocalDate { LocalDate(now) }

    /// "Updated 4h ago" for an offline copy, "Sign in to refresh" when the sign-in has lapsed but a
    /// cached copy is shown; `nil` when the data is fresh.
    private static func note(status: StoreStatus, fetchedAt: Date, now: Date) -> String? {
        switch status {
        case .offline: return SchoolFormat.age(of: fetchedAt, now: now).map { "Updated \($0)" }
        case .signedOut: return "Sign in to refresh"
        case .live, .disconnected: return nil
        }
    }

    /// The figures and lists a connected statement yields, after the design's store filter.
    struct Spending {
        /// The stores the design is filtered to; empty means all of them.
        let stores: [String]
        /// The prominent figure (small and Lock Screen sizes lead with it).
        let figure: Figure
        /// Recent charges, newest first; empty when the design hides the list.
        let charges: [StoreCharge]
        /// Each included store's running total, for the large size.
        let totals: [StoreTotal]
        /// Spent against the limit, 0...1, or `nil` when no limit is set.
        let progress: Double?
        /// "$82 of $300" for under a progress bar, or `nil` when no limit is set.
        let limitCaption: String?
        /// The amount spent, without cents, for the Lock Screen gauge, which always reads
        /// spent-against-limit so its ring and centre agree.
        let spentCompact: String
        /// The most recent charge's item, or `nil` when there are no charges.
        let latestItem: String?
        /// The store filter in words: "All stores" or the chosen stores joined.
        let storeSummary: String

        init(statement: StoreStatement, configuration: StoreConfiguration, now: Date) {
            let stores = configuration.stores
            self.stores = stores
            let spent = statement.total(in: stores)
            let latest = statement.latestCharge(in: stores)
            figure = Figure(highlight: configuration.highlight, spent: spent, limit: configuration.limit, latest: latest)
            charges = configuration.showsRecentCharges ? statement.charges(in: stores) : []
            totals = Self.totals(statement.totalsByStore, in: stores)
            latestItem = latest?.detail
            spentCompact = spent.usd(showsCents: false)
            if let limit = configuration.limit, limit > 0 {
                progress = Self.fraction(spent, of: limit)
                limitCaption = "\(spent.usd(showsCents: false)) of \(limit.usd(showsCents: false))"
            } else {
                progress = nil
                limitCaption = nil
            }
            storeSummary = stores.isEmpty ? "All stores" : stores.joined(separator: ", ")
        }

        /// The running totals for `stores` (matched case-insensitively); all of them when empty.
        private static func totals(_ totals: [StoreTotal], in stores: [String]) -> [StoreTotal] {
            guard !stores.isEmpty else { return totals }
            let keys = Set(stores.map(Self.key))
            return totals.filter { keys.contains(key($0.storeName)) }
        }

        private static func key(_ name: String) -> String {
            name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// `value / total`, clamped to 0...1.
        private static func fraction(_ value: Decimal, of total: Decimal) -> Double {
            guard total > 0 else { return 0 }
            let ratio = (value as NSDecimalNumber).dividing(by: total as NSDecimalNumber).doubleValue
            return min(max(ratio, 0), 1)
        }
    }

    /// The single figure a spending design leads with, from its highlight. The limit, when set, is
    /// drawn as a separate progress bar, so the figure's own caption stays a short label.
    struct Figure {
        /// The dollars behind `amount`, kept so tight spaces can drop the cents.
        let value: Decimal
        /// A short label under the figure: "Total spent", "Left", or the latest item.
        let caption: String

        init(highlight: StoreHighlight, spent: Decimal, limit: Decimal?, latest: StoreCharge?) {
            switch highlight {
            case .totalSpent:
                value = spent
                caption = limit == nil ? "Total spent" : "Spent"
            case .remaining:
                if let limit {
                    value = max(0, limit - spent)
                    caption = "Left"
                } else {
                    value = spent
                    caption = "Total spent"
                }
            case .latestCharge:
                if let latest {
                    value = latest.total
                    caption = latest.detail
                } else {
                    value = spent
                    caption = limit == nil ? "Total spent" : "Spent"
                }
            }
        }

        /// "$136.75".
        var amount: String { value.usd() }

        /// "$137", for a Lock Screen circle or gauge.
        var compactAmount: String { value.usd(showsCents: false) }
    }
}
