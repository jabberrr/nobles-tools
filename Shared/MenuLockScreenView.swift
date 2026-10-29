import SwiftUI
import WidgetKit
import NoblesKit

/// A menu on the Lock Screen: the featured dish alone, so it's never cut short by others. Where
/// the whole name doesn't fit, it gives way to `MenuItem.shortName`.
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

    // MARK: Inline

    /// "Lunch · Revved Up Macaroni & Cheese", losing the meal, then the dish's trimmings, to fit.
    private var inline: some View {
        let texts = inlineTexts
        return ViewThatFits {
            Label(texts.long, systemImage: content.mealSymbol)
            Label(texts.medium, systemImage: content.mealSymbol)
            Label(texts.short, systemImage: content.mealSymbol)
        }
        .symbolVariant(.fill)
    }

    private var inlineTexts: (long: String, medium: String, short: String) {
        let meal = content.mealName
        switch content.state {
        case .unavailable:
            return ("\(meal) menu unavailable", "Menu unavailable", "Unavailable")
        case .closed(let title):
            return (title, "No \(meal.lowercased()) menu", "No menu")
        case .filteredOut:
            return ("No matching \(meal.lowercased()) dishes", "No matching dishes", "No dishes")
        case .menu(let featured, _, _):
            return ("\(meal) · \(featured.item.name)", featured.item.name, featured.item.shortName)
        }
    }

    // MARK: Circular

    /// The meal's icon over the dish's name, or the name of the meal when the dish won't fit.
    @ViewBuilder private var circular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            ViewThatFits(in: .vertical) {
                circularDish(featured.item.name)
                circularDish(featured.item.shortName)
                circularLabel(content.mealName)
            }
        case .unavailable:
            circularLabel("Offline")
        case .closed:
            circularLabel("No menu")
        case .filteredOut:
            circularLabel("No dishes")
        }
    }

    private func circularDish(_ name: String) -> some View {
        VStack(spacing: 1) {
            Image(systemName: content.mealSymbol)
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Text(name)
                .font(.caption2.weight(.semibold))
        }
        .symbolVariant(.fill)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 7)
        .padding(.vertical, 8)
    }

    private func circularLabel(_ text: String) -> some View {
        VStack(spacing: 1) {
            Image(systemName: content.mealSymbol)
                .font(.title3.weight(.semibold))
                .widgetAccentable()
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .symbolVariant(.fill)
        .padding(6)
    }

    // MARK: Rectangular

    /// The meal and day, the dish on up to two lines, and its station when there's room.
    @ViewBuilder private var rectangular: some View {
        switch content.state {
        case .menu(let featured, _, _):
            ViewThatFits(in: .vertical) {
                rectangularDish(featured.item.name, station: featured)
                rectangularDish(featured.item.name)
                rectangularDish(featured.item.shortName)
                rectangularDish(featured.item.shortName, font: .subheadline.weight(.semibold))
            }
        case .unavailable:
            rectangularMessage("Menu unavailable")
        case .closed(let title):
            rectangularMessage(title)
        case .filteredOut:
            rectangularMessage("No matching dishes")
        }
    }

    private func rectangularDish(_ name: String, font: Font = .headline, station: Dish? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            rectangularHeader
            Text(name)
                .font(font)
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
