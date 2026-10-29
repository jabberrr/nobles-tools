import SwiftUI
import WidgetKit
import NoblesKit

/// A menu on the Lock Screen: the featured dish alone, so it's never cut short by others. Where
/// its whole name doesn't fit, `MenuItem.shortName` stands in, then the icon gives up its room,
/// and only then is the name cut at a word.
struct MenuLockScreenView: View {
    let content: MenuContent
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    /// A text to show, and whether the meal's icon goes with it.
    private struct Variant {
        let text: String
        var showsIcon = true
    }

    /// The dish's name and short name, first with the icon and then without, then the short name
    /// cut at words.
    private func variants(of dish: Dish) -> [Variant] {
        let names = [dish.item.name, dish.item.shortName]
        return names.map { Variant(text: $0) }
            + names.map { Variant(text: $0, showsIcon: false) }
            + dish.item.shortName.cutsAtWords(limit: 3).map { Variant(text: $0, showsIcon: false) }
    }

    // MARK: Inline

    /// "Lunch · Revved Up Macaroni & Cheese", giving up the meal, the dish's trimmings, then the
    /// icon to fit.
    private var inline: some View {
        FirstFitting(variants: inlineVariants) { variant in
            if variant.showsIcon {
                Label(variant.text, systemImage: content.mealSymbol)
                    .symbolVariant(.fill)
            } else {
                Text(variant.text)
            }
        }
    }

    private var inlineVariants: [Variant] {
        let meal = content.mealName
        switch content.state {
        case .unavailable:
            return ["\(meal) menu unavailable", "Menu unavailable", "Unavailable"].map { Variant(text: $0) }
        case .closed(let sentence):
            return [sentence, content.noMenuText, "No menu"].map { Variant(text: $0) }
        case .filteredOut:
            return ["No matching \(meal.lowercased()) dishes", "No matching dishes", "No dishes"].map { Variant(text: $0) }
        case .menu(let featured, _, _):
            return [Variant(text: "\(meal) · \(featured.item.name)")] + variants(of: featured)
        }
    }

    // MARK: Circular

    /// The meal's icon over the dish's name, or over a word when there's no dish to show.
    @ViewBuilder private var circular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            FirstFitting(variants: variants(of: featured), axes: .vertical) { variant in
                circularLabel(variant.text, symbolFont: variant.showsIcon ? Font.caption.weight(.semibold) : nil)
            }
        case .unavailable:
            circularLabel("Offline")
        case .closed:
            circularLabel("No menu")
        case .filteredOut:
            circularLabel("No dishes")
        }
    }

    /// `text` under the meal's icon in `symbolFont`, or alone when that's `nil`.
    private func circularLabel(_ text: String, symbolFont: Font? = .title3.weight(.semibold)) -> some View {
        VStack(spacing: 1) {
            if let symbolFont {
                Image(systemName: content.mealSymbol)
                    .font(symbolFont)
                    .widgetAccentable()
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .symbolVariant(.fill)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
    }

    // MARK: Rectangular

    /// The meal and day, the dish on up to two lines, and its station when there's room and the
    /// design names stations.
    @ViewBuilder private var rectangular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            let station = content.showsStations && !featured.station.isEmpty ? featured : nil
            let names = [featured.item.name, featured.item.shortName] + featured.item.shortName.cutsAtWords(limit: 2)
            let variants = [featured.item.name, featured.item.shortName].map { (name: $0, station: station) }
                + names.map { (name: $0, station: Dish?.none) }
            FirstFitting(variants: variants, axes: .vertical) { variant in
                rectangularDish(variant.name, station: variant.station)
            }
        case .unavailable:
            rectangularMessage("Menu unavailable")
        case .closed:
            rectangularMessage(content.noMenuText)
        case .filteredOut:
            rectangularMessage("No matching dishes")
        }
    }

    private func rectangularDish(_ name: String, station: Dish?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            rectangularHeader
            Text(name)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let station {
                iconLabel(station.station, symbol: station.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rectangularMessage(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            rectangularHeader
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Lunch · Today" after the meal's icon.
    private var rectangularHeader: some View {
        iconLabel(content.day.map { "\(content.mealName) · \($0)" } ?? content.mealName, symbol: content.mealSymbol)
            .font(.footnote.weight(.semibold))
            .widgetAccentable()
    }

    /// `text` after `symbol` in a fixed-width column, so labels with different icons line up.
    private func iconLabel(_ text: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .symbolVariant(.fill)
                .frame(width: 18)
            Text(text)
        }
        .lineLimit(1)
    }
}
