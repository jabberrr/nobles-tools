import Foundation

/// A lenient decoder for one `get_charges.php` body, mapping its string-money, string-date JSON onto
/// the `Store` models. Every field tolerates a missing, null or mistyped value so one odd row can't
/// fail the whole statement. A body missing `ok: true` or the `charges` array decodes with
/// `charges == nil`, which `StoreService.parse` reads as a sign-in wall rather than real data.
struct StoreChargesResponse: Decodable {
    let ok: Bool
    /// The charges, or `nil` when the response carries no `charges` array (e.g. a not-signed-in body).
    let charges: [StoreCharge]?
    let totalsByStore: [StoreTotal]
    let grandTotal: Decimal

    private enum CodingKeys: String, CodingKey {
        case ok, charges
        case totalsByStore = "totals_by_store"
        case grandTotals = "grand_totals"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = container.decode(.ok, or: false)
        if container.contains(.charges), let rows = container.lenient([Lossy<ChargeRow>].self, forKey: .charges) {
            charges = rows.compactMap { $0.value?.charge }
        } else {
            charges = nil
        }
        let totalRows = container.lenient([Lossy<TotalRow>].self, forKey: .totalsByStore) ?? []
        totalsByStore = totalRows.compactMap { $0.value?.total }
        let grand = container.lenient(GrandTotals.self, forKey: .grandTotals)?.total
        grandTotal = grand ?? totalsByStore.reduce(0) { $0 + $1.total }
    }
}

/// One element of `charges`; `charge` is `nil` for a row without an id or a readable `created` time.
private struct ChargeRow: Decodable {
    let charge: StoreCharge?

    private enum CodingKeys: String, CodingKey {
        case chargeID = "charge_id"
        case storeName = "store_name"
        case transType = "trans_type"
        case description, quantity
        case totalCost = "total_cost"
        case salesTax = "sales_tax"
        case created
        case postedOn = "posted_on"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.integer(forKey: .chargeID),
              let madeAt = container.text(forKey: .created).flatMap(StoreChargesParsing.date(from:))
        else {
            charge = nil
            return
        }
        charge = StoreCharge(
            id: id,
            storeName: container.text(forKey: .storeName) ?? "",
            transactionType: container.text(forKey: .transType),
            detail: container.text(forKey: .description) ?? "",
            quantity: container.integer(forKey: .quantity) ?? 1,
            amount: container.money(forKey: .totalCost),
            tax: container.money(forKey: .salesTax),
            madeAt: madeAt,
            postedOn: container.text(forKey: .postedOn).flatMap(LocalDate.init(iso:))
        )
    }
}

/// One element of `totals_by_store`; `total` is `nil` without a store name.
private struct TotalRow: Decodable {
    let total: StoreTotal?

    private enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case totalCost = "total_cost"
        case salesTax = "sales_tax"
        case grandTotal = "grand_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let name = container.text(forKey: .storeName) else {
            total = nil
            return
        }
        total = StoreTotal(
            storeName: name,
            amount: container.money(forKey: .totalCost),
            tax: container.money(forKey: .salesTax),
            total: container.money(forKey: .grandTotal)
        )
    }
}

/// The `grand_totals` object; only its `grand_total` is used.
private struct GrandTotals: Decodable {
    let total: Decimal

    private enum CodingKeys: String, CodingKey {
        case grandTotal = "grand_total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = container.money(forKey: .grandTotal)
    }
}

/// Field formats used only by the charges feed.
enum StoreChargesParsing {
    /// A `created` stamp like "2026-11-09 14:59", read as UTC into a `Date`; `nil` without a readable
    /// date. A stamp without a readable time keeps its day: midnight that day, school time.
    ///
    /// The feed writes UTC, not school time: real purchases fall inside the cafes' opening hours only
    /// when read as UTC, and they shift an hour in UTC when daylight saving time ends.
    static func date(from text: String) -> Date? {
        let parts = text.trimmed.split(separator: " ", maxSplits: 1)
        guard let day = parts.first.flatMap({ LocalDate(iso: String($0)) }) else { return nil }
        let clock = parts.dropFirst().first?.split(separator: ":") ?? []
        guard let hour = clock.first.flatMap({ Int($0) }) else { return day.startOfDay() }
        let minute = clock.count > 1 ? Int(clock[1]) ?? 0 : 0
        return day.at(hour: hour, minute: minute, in: .utc)
    }
}

private extension Calendar {
    /// Gregorian, in UTC: the charges feed's clock.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

private extension KeyedDecodingContainer {
    /// A money field, written as a string like "4.00" (or, defensively, a bare number); `0` when
    /// it's missing or unreadable.
    func money(forKey key: Key) -> Decimal {
        if let text = text(forKey: key), let value = Decimal(string: text, locale: .posix) {
            return value
        }
        if let number = lenient(Double.self, forKey: key) {
            return Decimal(number)
        }
        return 0
    }
}

private extension Locale {
    /// Fixes the decimal separator to ".", so money parses the same in every device locale.
    static let posix = Locale(identifier: "en_US_POSIX")
}
