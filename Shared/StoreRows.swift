import SwiftUI
import WidgetKit
import NoblesKit

/// A charge on one row: the store's icon tile, the item (shortened to fit, never mid-word), the
/// store it was bought at, and the amount over the day it was made.
struct ChargeRow: View {
    let charge: StoreCharge
    /// Today in school time, for the relative date.
    let today: LocalDate
    let colors: ThemeColors

    var body: some View {
        HStack(spacing: 10) {
            SymbolTile(symbol: StoreSymbol.name(for: charge.storeName), size: 26, colors: colors)
            VStack(alignment: .leading, spacing: 1) {
                FirstFitting(variants: itemVariants, axes: .horizontal) { Text($0) }
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(charge.storeName)
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(charge.total.usd())
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                Text(SchoolFormat.shortRelativeDay(LocalDate(charge.madeAt), from: today))
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }

    /// The item in full, then cut short at word boundaries if even that won't fit.
    private var itemVariants: [String] {
        [charge.detail] + charge.detail.cutsAtWords(limit: 2)
    }
}

/// A store's running total: its icon, its name, and what's been spent there.
struct StoreTotalRow: View {
    let total: StoreTotal
    let colors: ThemeColors

    var body: some View {
        HStack(spacing: 10) {
            SymbolTile(symbol: StoreSymbol.name(for: total.storeName), size: 24, colors: colors)
            Text(total.storeName)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(total.total.usd())
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
        }
    }
}
