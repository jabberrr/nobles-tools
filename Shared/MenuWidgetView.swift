import SwiftUI
import WidgetKit
import NoblesKit

/// A dining-menu design rendered at one widget size. The widget and the app's previews both use it.
struct MenuWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The menu to show, or `nil` when it couldn't be loaded.
    let upcoming: UpcomingMenu?
    /// The moment on screen (the timeline entry's date), for "Today" and "Tomorrow".
    let now: Date

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryRectangular: rectangular
        default: system
        }
    }

    // MARK: State

    private var configuration: MenuConfiguration { design.menuConfiguration ?? MenuConfiguration() }

    private var today: LocalDate { LocalDate(now) }

    private var mealName: String { upcoming?.meal.displayName ?? configuration.meal.displayName }

    private var mealSymbol: String { (upcoming?.meal ?? configuration.meal.meal)?.symbolName ?? "fork.knife" }

    private enum MenuState {
        /// Nothing could be loaded.
        case unavailable
        /// Nothing is published for this meal.
        case closed(title: String)
        /// A menu is published, but the design's filter hides every dish.
        case filteredOut
        /// The filtered menu.
        case menu(DailyMenu)
    }

    private var state: MenuState {
        guard let upcoming else { return .unavailable }
        guard let menu = upcoming.menu else { return .closed(title: closedTitle(upcoming)) }
        let filtered = menu.filtered(by: configuration.filter)
        return filtered.isEmpty ? .filteredOut : .menu(filtered)
    }

    /// "No dinner menu today", "No lunch menu on Sat, Oct 24", "No breakfast menu published".
    private func closedTitle(_ upcoming: UpcomingMenu) -> String {
        let meal = upcoming.meal.displayName.lowercased()
        guard upcoming.meal != .breakfast else { return "No \(meal) menu published" }
        let day = SchoolFormat.relativeDay(upcoming.date, from: today)
        let when = abs(today.days(until: upcoming.date)) <= 1 ? day.lowercased() : "on \(day)"
        return "No \(meal) menu \(when)"
    }

    // MARK: System sizes

    private var system: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            header
            switch state {
            case .unavailable:
                WidgetMessage(symbol: "wifi.slash", title: "Menu unavailable", detail: "Will try again soon", colors: colors)
            case .closed(let title):
                WidgetMessage(symbol: "fork.knife", title: title, colors: colors)
            case .filteredOut:
                WidgetMessage(
                    symbol: "line.3.horizontal.decrease.circle",
                    title: "No matching dishes",
                    detail: configuration.filter.summaryText,
                    colors: colors
                )
            case .menu(let menu):
                dishes(menu)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: mealSymbol)
            Text(mealName)
            Spacer(minLength: 4)
            if let upcoming {
                Text(SchoolFormat.relativeDay(upcoming.date, from: today))
                    .foregroundStyle(colors.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(colors.accent)
        .lineLimit(1)
    }

    @ViewBuilder private func dishes(_ menu: DailyMenu) -> some View {
        switch family {
        case .systemSmall:
            FittingList(items: menu.highlights, capacity: 5, spacing: 4, overflowColor: colors.secondary) { item in
                Text(item.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(2)
            }
        case .systemMedium:
            columns(menu, capacity: 12, font: .caption)
        default:
            columns(menu, capacity: 24, font: .footnote)
        }
    }

    /// As many dishes as fit, in menu order, in two columns split between stations where
    /// possible. A "+N more" for the rest goes at the end, under both columns.
    private func columns(_ menu: DailyMenu, capacity: Int, font: Font) -> some View {
        FittingPrefix(items: DishRow.rows(of: menu), capacity: capacity, spacing: 4, overflowColor: colors.secondary) { shown in
            let halves = DishRow.split(shown)
            HStack(alignment: .top, spacing: 12) {
                column(halves.left, font: font)
                column(halves.right, font: font)
            }
        }
    }

    private func column(_ rows: [DishRow], font: Font) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                dishRow(row, font: font)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dishRow(_ row: DishRow, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if configuration.showsSectionHeaders, row.startsSection, !row.section.isEmpty {
                Text(row.section.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(colors.accent)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            Text(row.item.name)
                .font(font)
                .lineLimit(2)
        }
    }

    // MARK: Lock Screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(upcoming.map { "\(mealName) · \(SchoolFormat.relativeDay($0.date, from: today))" } ?? mealName,
                  systemImage: mealSymbol)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            switch state {
            case .unavailable:
                Text("Menu unavailable").font(.caption).foregroundStyle(.secondary)
            case .closed(let title):
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            case .filteredOut:
                Text("No matching dishes").font(.caption).foregroundStyle(.secondary)
            case .menu(let menu):
                FittingList(items: menu.highlights, capacity: 3, spacing: 0) { item in
                    Text(item.name).font(.caption).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inline: some View {
        Label(inlineText, systemImage: mealSymbol)
    }

    /// "Lunch · Revved Up Macaroni & Cheese"
    private var inlineText: String {
        switch state {
        case .unavailable: "\(mealName) · Unavailable"
        case .closed: "No \(mealName.lowercased()) menu"
        case .filteredOut: "\(mealName) · No matching dishes"
        case .menu(let menu): "\(mealName) · \(menu.highlights.first?.name ?? "")"
        }
    }
}

/// A dish laid out in a menu widget, with the station it came from.
private struct DishRow {
    var section: String
    var item: MenuItem
    /// Whether this is the first dish shown from its station, so the station's name goes above it.
    var startsSection: Bool

    /// Every dish in `menu`, in order.
    static func rows(of menu: DailyMenu) -> [DishRow] {
        menu.sections.flatMap { section in
            section.items.enumerated().map { index, item in
                DishRow(section: section.title, item: item, startsSection: index == 0)
            }
        }
    }

    /// Splits `rows` into two columns at the station boundary nearest the middle. When that
    /// boundary would leave the columns lopsided, it splits mid-station instead, and the right
    /// column repeats the station's name.
    static func split(_ rows: [DishRow]) -> (left: [DishRow], right: [DishRow]) {
        guard rows.count > 1 else { return (rows, []) }
        let middle = (rows.count + 1) / 2
        let boundaries = rows.indices.filter { $0 > 0 && rows[$0].startsSection }
        var cut = middle
        if let nearest = boundaries.min(by: { abs($0 - middle) < abs($1 - middle) }),
           abs(nearest - middle) <= max(1, rows.count / 4) {
            cut = nearest
        }
        var right = Array(rows[cut...])
        right[0].startsSection = true
        return (Array(rows[..<cut]), right)
    }
}

extension MenuFilter {
    /// A readable description, e.g. "Just Hot Entree, Dessert" or "Everything except Soup Station".
    /// With no stations chosen, "Just…" and "Everything Except…" filter nothing: "All stations".
    var summaryText: String {
        switch self {
        case .everything, .entreesOnly, .withoutSaladsAndSoups:
            style.displayName
        case .only(let sections):
            sections.isEmpty ? "All stations" : "Just " + sections.joined(separator: ", ")
        case .excluding(let sections):
            sections.isEmpty ? "All stations" : "Everything except " + sections.joined(separator: ", ")
        }
    }
}

extension UpcomingMenu {
    /// Sample content for placeholders, the widget gallery and offline previews.
    static func placeholder(for selection: MealSelection, now: Date = .now) -> UpcomingMenu {
        let meal = selection.meal ?? .lunch
        let date = LocalDate(now)
        return UpcomingMenu(
            meal: meal,
            date: date,
            menu: .sample(meal: meal, date: date),
            validUntil: meal.serviceEnd(on: date)
        )
    }
}
