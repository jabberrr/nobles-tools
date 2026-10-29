import SwiftUI
import WidgetKit
import NoblesKit

/// A dining-menu design rendered at one widget size. The widget and the app's previews both use it.
///
/// Every size leads with the design's featured dish (`MenuConfiguration.featuredDish(in:)`): the
/// Lock Screen shows it alone, and the Home Screen follows it with as many other dishes as fit
/// whole.
struct MenuWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The menu to show, or `nil` when it couldn't be loaded.
    let upcoming: UpcomingMenu?
    /// The moment on screen (the timeline entry's date), for "Today" and "Tomorrow".
    let now: Date

    var body: some View {
        let configuration = design.menuConfiguration ?? MenuConfiguration()
        let content = MenuContent(configuration: configuration, upcoming: upcoming, now: now)
        if family.isAccessory {
            MenuLockScreenView(content: content, family: family)
        } else {
            MenuHomeScreenView(content: content, family: family, colors: colors, configuration: configuration)
        }
    }
}

/// A menu on the Home Screen: the meal and day, the featured dish, then the other dishes that fit.
private struct MenuHomeScreenView: View {
    let content: MenuContent
    let family: WidgetFamily
    let colors: ThemeColors
    let configuration: MenuConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            WidgetHeader(symbol: content.mealSymbol, title: content.mealName, detail: content.day, colors: colors)
            switch content.state {
            case .unavailable:
                WidgetMessage(symbol: "wifi.slash", title: "Menu unavailable", detail: "Will try again soon", colors: colors)
            case .closed(let title):
                WidgetMessage(symbol: "fork.knife", title: title, colors: colors)
            case .filteredOut:
                WidgetMessage(
                    symbol: "line.3.horizontal.decrease",
                    title: "No matching dishes",
                    detail: configuration.filter.summaryText,
                    colors: colors
                )
            case .menu(let featured, let others, let stations):
                switch family {
                case .systemSmall: small(featured, others)
                case .systemMedium: medium(featured, others)
                default: large(featured, stations)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var showsStations: Bool { configuration.showsSectionHeaders }

    /// The featured dish, then one-line-icon rows for the rest.
    private func small(_ featured: Dish, _ others: [Dish]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FeaturedDishView(dish: featured, showsStation: showsStations, colors: colors)
                .layoutPriority(1)
            otherDishes(others, capacity: 3)
        }
    }

    /// The featured dish on the left, a list of the rest on the right.
    @ViewBuilder private func medium(_ featured: Dish, _ others: [Dish]) -> some View {
        if others.isEmpty {
            FeaturedDishView(dish: featured, prominence: .large, showsStation: showsStations, colors: colors)
        } else {
            HStack(alignment: .top, spacing: 12) {
                FeaturedDishView(dish: featured, showsStation: showsStations, colors: colors)
                    .frame(width: 136, alignment: .topLeading)
                Rectangle()
                    .fill(colors.track)
                    .frame(width: 1)
                otherDishes(others, capacity: 4)
            }
        }
    }

    /// The featured dish on a card, then the rest by station in two columns.
    private func large(_ featured: Dish, _ stations: [MenuSection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FeaturedDishView(dish: featured, prominence: .large, showsStation: showsStations, colors: colors)
                .padding(12)
                .background(colors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .layoutPriority(1)
            StationColumns(stations: stations, showsStations: showsStations, colors: colors)
        }
    }

    private func otherDishes(_ dishes: [Dish], capacity: Int) -> some View {
        FittingList(items: dishes, capacity: capacity, spacing: 5, overflowColor: colors.secondary) { dish in
            CompactDishRow(dish: dish, colors: colors)
        }
    }
}
