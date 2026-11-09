import Foundation

extension Decimal {
    /// A US-dollar string, e.g. "$4.00" or, with `showsCents: false`, "$137". Rounds half-up to the
    /// chosen precision. Kept here so the app, the widget and tests format money identically.
    public func usd(showsCents: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = showsCents ? 2 : 0
        formatter.maximumFractionDigits = showsCents ? 2 : 0
        return formatter.string(from: self as NSDecimalNumber) ?? "$\(self)"
    }
}
