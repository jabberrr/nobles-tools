import SwiftUI
import WidgetKit
import NoblesKit

/// Every kind of widget at every size, drawn from fixed sample data at a fixed moment, in several
/// themes, and with the long names and empty states layouts must hold up to. Shown in Xcode's
/// canvas, and rendered to `docs/widgets` by the `WidgetSnapshots` tests so layouts can be
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
        (menuVariants + countdownVariants + scoresVariants).flatMap { variant in
            variant.families.map { family in
                Entry(name: "\(variant.name)-\(family.galleryName)", view: AnyView(tile(variant, family)))
            }
        }
    }

    // MARK: Variants

    /// One design to render, the sizes to render it at, the data it shows, and the appearance.
    private struct Variant {
        let name: String
        let design: WidgetDesign
        let families: [WidgetFamily]
        var colorScheme: ColorScheme = .light
        /// The menu a menu design shows; `nil` shows it as unavailable.
        var menu: UpcomingMenu? = nil
        /// The games a scores design shows; `nil` shows them as unavailable.
        var scoreboard: Scoreboard? = nil
    }

    private static var homeScreen: [WidgetFamily] { [.systemSmall, .systemMedium, .systemLarge] }

    private static func design(_ content: WidgetContent, theme: Theme = Theme()) -> WidgetDesign {
        WidgetDesign(name: content.kind.displayName, theme: theme, content: content)
    }

    private static var menuVariants: [Variant] {
        let lunch = design(.menu(MenuConfiguration()))
        let dinner = design(
            .menu(MenuConfiguration(meal: .dinner, filter: .withoutSaladsAndSoups)),
            theme: Theme(palette: .navy, font: .rounded)
        )
        let halloween = design(.menu(MenuConfiguration()), theme: Theme(palette: .sunset, font: .serif))
        let vegan = design(
            .menu(MenuConfiguration(showsSectionHeaders: false, featuredStation: "Vegan Entree")),
            theme: Theme(palette: .graphite, background: .solid)
        )
        let closed = design(.menu(MenuConfiguration(meal: .dinner)), theme: Theme(palette: .paper))
        let lunchMenu = GallerySamples.menu(.lunch)
        return [
            Variant(name: "menu-lunch", design: lunch, families: WidgetKind.menu.widgetFamilies, menu: lunchMenu),
            Variant(name: "menu-dinner-navy", design: dinner, families: homeScreen, menu: GallerySamples.menu(.dinner)),
            Variant(name: "menu-lunch-dark", design: lunch, families: [.systemMedium], colorScheme: .dark, menu: lunchMenu),
            Variant(
                name: "menu-halloween-sunset",
                design: halloween,
                families: homeScreen + [.accessoryRectangular],
                menu: GallerySamples.halloweenLunch
            ),
            Variant(
                name: "menu-vegan-graphite",
                design: vegan,
                families: [.systemSmall, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline],
                menu: lunchMenu
            ),
            Variant(name: "menu-closed-paper", design: closed, families: [.systemSmall], menu: GallerySamples.noDinner),
            Variant(name: "menu-unavailable", design: lunch, families: [.systemMedium], menu: nil),
        ]
    }

    private static var countdownVariants: [Variant] {
        let year = design(.countdown(CountdownConfiguration(target: .year, style: .ring)))
        let quarter = design(
            .countdown(CountdownConfiguration(target: .quarter, counting: .weekdays, style: .bar)),
            theme: Theme(palette: .forest, font: .serif)
        )
        let semester = design(.countdown(CountdownConfiguration(target: .semester, style: .number)))
        return [
            Variant(name: "countdown-year", design: year, families: WidgetKind.countdown.widgetFamilies),
            Variant(name: "countdown-quarter-forest", design: quarter, families: homeScreen),
            Variant(name: "countdown-semester-dark", design: semester, families: [.systemSmall, .accessoryCircular], colorScheme: .dark),
        ]
    }

    private static var scoresVariants: [Variant] {
        let scores = design(.scores(ScoresConfiguration()))
        let crimson = design(.scores(ScoresConfiguration()), theme: Theme(palette: .crimson, background: .solid))
        let allLevels = design(.scores(ScoresConfiguration(varsityOnly: false)), theme: Theme(palette: .paper))
        let squash = ScoresConfiguration(sports: ["Girls Squash"])
        let sample = GallerySamples.scoreboard
        return [
            Variant(name: "scores", design: scores, families: WidgetKind.scores.widgetFamilies, scoreboard: sample),
            Variant(name: "scores-crimson", design: crimson, families: [.systemSmall], scoreboard: sample),
            Variant(name: "scores-dark", design: scores, families: [.systemMedium], colorScheme: .dark, scoreboard: sample),
            Variant(
                name: "scores-long-paper",
                design: allLevels,
                families: [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline],
                scoreboard: GallerySamples.longNamesScoreboard
            ),
            Variant(
                name: "scores-empty",
                design: design(.scores(squash)),
                families: [.systemSmall],
                scoreboard: Scoreboard(games: [], configuration: squash, now: now)
            ),
            Variant(name: "scores-unavailable", design: scores, families: [.accessoryRectangular], scoreboard: nil),
        ]
    }

    // MARK: Drawing

    private static func tile(_ variant: Variant, _ family: WidgetFamily) -> some View {
        WidgetPreviewFrame(family: family, theme: variant.design.theme) { colors in
            DesignWidgetContent(
                design: variant.design,
                family: family,
                colors: colors,
                menu: variant.menu,
                scoreboard: variant.scoreboard,
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
