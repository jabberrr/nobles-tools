import SwiftUI
import WidgetKit
import NoblesKit

/// A menu on the Lock Screen: the featured dish alone, so it's never cut short by others. Where
/// its whole name doesn't fit, `MenuItem.shortName` stands in, then that cut at a word.
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

    /// The featured dish's name, then shorter forms of it for tighter spaces: `shortName`, then
    /// that cut at words.
    private func names(of dish: Dish) -> [String] {
        [dish.item.name, dish.item.shortName] + dish.item.shortName.cutsAtWords(limit: 3)
    }

    // MARK: Inline

    /// "Lunch · Revved Up Macaroni & Cheese", losing the meal, then the dish's trimmings, then its
    /// last words, to fit.
    private var inline: some View {
        FirstFitting(variants: inlineTexts) { text in
            Label(text, systemImage: content.mealSymbol)
        }
        .symbolVariant(.fill)
    }

    private var inlineTexts: [String] {
        let meal = content.mealName
        switch content.state {
        case .unavailable:
            return ["\(meal) menu unavailable", "Menu unavailable", "Unavailable"]
        case .closed(let sentence):
            return [sentence, content.noMenuText, "No menu"]
        case .filteredOut:
            return ["No matching \(meal.lowercased()) dishes", "No matching dishes", "No dishes"]
        case .menu(let featured, _, _):
            return ["\(meal) · \(featured.item.name)"] + names(of: featured)
        }
    }

    // MARK: Circular

    /// The meal's icon over the dish's name on up to three lines, or over a word when it's not on.
    @ViewBuilder private var circular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            FirstFitting(variants: names(of: featured) + [content.mealName], axes: .vertical) { name in
                circularLabel(name, symbolFont: .caption.weight(.semibold))
            }
        case .unavailable:
            circularLabel("Offline")
        case .closed:
            circularLabel("No menu")
        case .filteredOut:
            circularLabel("No dishes")
        }
    }

    private func circularLabel(_ text: String, symbolFont: Font = .title3.weight(.semibold)) -> some View {
        VStack(spacing: 1) {
            Image(systemName: content.mealSymbol)
                .font(symbolFont)
                .widgetAccentable()
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .symbolVariant(.fill)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
    }

    // MARK: Rectangular

    /// The meal and day, the dish on up to two lines, and its station when there's room.
    @ViewBuilder private var rectangular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            // The whole name with its station, then shorter and shorter names without.
            let variants = [(name: featured.item.name, station: Optional(featured))]
                + names(of: featured).map { (name: $0, station: Dish?.none) }
            FirstFitting(variants: variants, axes: .vertical) { variant in
                rectangularDish(variant.name, station: variant.station)
                    .fixedSize(horizontal: false, vertical: true)
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
            if let station, !station.station.isEmpty {
                Label(station.station, systemImage: station.symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .symbolVariant(.fill)
                    .lineLimit(1)
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
        Label(content.day.map { "\(content.mealName) · \($0)" } ?? content.mealName, systemImage: content.mealSymbol)
            .font(.footnote.weight(.semibold))
            .symbolVariant(.fill)
            .lineLimit(1)
            .widgetAccentable()
    }
}
