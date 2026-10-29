import SwiftUI
import WidgetKit
import NoblesKit

/// Every kind of widget at every size, drawn from fixed sample data at a fixed moment. Shown in
/// Xcode's canvas, and rendered to `docs/widgets` by the `WidgetSnapshots` tests so layouts can be
/// checked without a device.
enum WidgetGallery {
    struct Entry: Identifiable {
        /// File-name-friendly, e.g. "menu-lunch-small".
        let name: String
        let view: AnyView

        var id: String { name }
    }

    /// Tuesday, October 27, 2026, 11:30 a.m. at school: before lunch ends, in Quarter 1.
    static let now = LocalDate(year: 2026, month: 10, day: 27).at(hour: 11, minute: 30)

    static var entries: [Entry] {
        variants.flatMap { variant in
            variant.families.map { family in
                Entry(name: "\(variant.name)-\(family.galleryName)", view: AnyView(tile(variant, family)))
            }
        }
    }

    // MARK: Variants

    /// One design to render, the sizes to render it at, and the appearance to render it in.
    private struct Variant {
        let name: String
        let design: WidgetDesign
        var families: [WidgetFamily]
        var colorScheme: ColorScheme = .light
    }

    private static var variants: [Variant] {
        let menu = WidgetDesign(name: "Lunch", content: .menu(MenuConfiguration(meal: .lunch)))
        let dinner = WidgetDesign(
            name: "Dinner",
            theme: Theme(palette: .navy, font: .rounded),
            content: .menu(MenuConfiguration(meal: .dinner, filter: .withoutSaladsAndSoups))
        )
        let year = WidgetDesign(name: "Year", content: .countdown(CountdownConfiguration(target: .year, style: .ring)))
        let quarter = WidgetDesign(
            name: "Quarter",
            theme: Theme(palette: .forest, font: .serif),
            content: .countdown(CountdownConfiguration(target: .quarter, counting: .weekdays, style: .bar))
        )
        let scores = WidgetDesign(name: "Scores", content: .scores(ScoresConfiguration()))
        let scoresThemed = WidgetDesign(
            name: "Scores",
            theme: Theme(palette: .crimson, background: .solid),
            content: .scores(ScoresConfiguration())
        )
        let homeScreen: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        return [
            Variant(name: "menu-lunch", design: menu, families: WidgetKind.menu.widgetFamilies),
            Variant(name: "menu-dinner-navy", design: dinner, families: homeScreen),
            Variant(name: "menu-lunch-dark", design: menu, families: [.systemMedium], colorScheme: .dark),
            Variant(name: "countdown-year", design: year, families: WidgetKind.countdown.widgetFamilies),
            Variant(name: "countdown-quarter-forest", design: quarter, families: homeScreen),
            Variant(name: "countdown-year-dark", design: year, families: [.systemSmall], colorScheme: .dark),
            Variant(name: "scores", design: scores, families: WidgetKind.scores.widgetFamilies),
            Variant(name: "scores-crimson", design: scoresThemed, families: homeScreen),
            Variant(name: "scores-dark", design: scores, families: [.systemMedium], colorScheme: .dark),
        ]
    }

    // MARK: Data

    private static func menu(for design: WidgetDesign) -> UpcomingMenu {
        let meal = design.menuConfiguration?.meal.meal ?? .lunch
        let day = LocalDate(now)
        return UpcomingMenu(meal: meal, date: day, menu: .sample(meal: meal, date: day), validUntil: meal.serviceEnd(on: day))
    }

    private static func tile(_ variant: Variant, _ family: WidgetFamily) -> some View {
        WidgetPreviewFrame(family: family, theme: variant.design.theme) { colors in
            DesignWidgetContent(
                design: variant.design,
                family: family,
                colors: colors,
                menu: menu(for: variant.design),
                scoreboard: .sample(now: now),
                calendar: .nobles2026_27,
                now: now
            )
        }
        .padding(16)
        .background(variant.colorScheme == .dark ? Color(hex: 0x1C1C1E) : Color(hex: 0xE9EDF2))
        .environment(\.colorScheme, variant.colorScheme)
    }
}

extension WidgetFamily {
    /// e.g. "small", "lock-rectangular".
    var galleryName: String {
        switch self {
        case .systemSmall: "small"
        case .systemMedium: "medium"
        case .systemLarge: "large"
        case .systemExtraLarge: "extra-large"
        case .accessoryCircular: "lock-circular"
        case .accessoryRectangular: "lock-rectangular"
        case .accessoryInline: "lock-inline"
        default: "other"
        }
    }
}

#Preview("Widget gallery") {
    ScrollView {
        LazyVStack(spacing: 8) {
            ForEach(WidgetGallery.entries) { entry in
                entry.view
                Text(entry.name).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
