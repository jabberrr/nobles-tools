import Foundation
import NoblesKit

/// Fixed data for the widget gallery, from real October 2026 menus and games: everyday content,
/// the longest names layouts have to hold, and the empty states.
enum GallerySamples {
    /// The day the gallery is drawn on.
    static var today: LocalDate { LocalDate(WidgetGallery.now) }

    /// The sample menu for `meal`, served today.
    static func menu(_ meal: Meal) -> UpcomingMenu {
        upcoming(meal, on: today, .sample(meal: meal, date: today))
    }

    /// Friday, October 30: Halloween, with no dinner.
    private static let friday = LocalDate(year: 2026, month: 10, day: 30)

    /// The real Halloween lunch: themed dishes with long names, and a cookie station with a long
    /// title.
    static var halloweenLunch: UpcomingMenu {
        let menu = dailyMenu(.lunch, on: friday, stations: [
            ("Soup Station", ["Black Widow Soup, Sour Cream & Scallions"]),
            ("Hot Entree", ["Monster Chicken Fingers", "Ghoulish Dipping Sauces"]),
            ("Sides", ["Slash & Cuts' Fries", "Steamed Zombie Brains, Sea Salt & Cracked Pepper"]),
            ("Dracula's Cookie Extravaganza", [
                "Chocolate Chip, Snickerdoodle, Oatmeal",
                "Cranberry-White Chocolate, M&M, Double Chocolate Cookies",
            ]),
            ("Weekly Composed Salad", ["Mini Caprese Salad, Arugula & Balsamic Glaze"]),
        ])
        return upcoming(.lunch, on: friday, menu)
    }

    /// No dinner published: Fridays have none.
    static var noDinner: UpcomingMenu {
        UpcomingMenu(meal: .dinner, date: friday, menu: nil, validUntil: friday.adding(days: 1).startOfDay())
    }

    /// The sample scoreboard.
    static var scoreboard: Scoreboard { .sample(now: WidgetGallery.now) }

    /// Real opponents with the longest names, at every level.
    static var longNamesScoreboard: Scoreboard {
        func day(_ offset: Int, at hour: Int = 12, _ minute: Int = 0) -> Date {
            today.adding(days: offset).at(hour: hour, minute: minute)
        }
        let games = [
            Game(id: "long-1", sport: "Girls Field Hockey", level: "Middle School", opponent: "Buckingham Browne & Nichols School",
                 start: day(-1), hasStartTime: false, status: .final, score: GameScore(outcome: .win, nobles: 4, opponent: 1)),
            Game(id: "long-2", sport: "Girls Volleyball", level: "JV A", opponent: "The Cambridge School of Weston",
                 start: day(-2), hasStartTime: false, status: .final, score: GameScore(outcome: .loss, nobles: 1, opponent: 3)),
            Game(id: "long-3", sport: "Boys Cross Country", level: "Varsity", opponent: "St. Sebastian's School",
                 start: day(-3), hasStartTime: false, status: .final, score: GameScore(outcome: .tie)),
            Game(id: "long-4", sport: "Boys Soccer", level: "Varsity", opponent: "Beaver Country Day School", isHome: false,
                 start: day(1, at: 15, 30), location: "Beaver Country Day School", status: .scheduled),
        ]
        return Scoreboard(games: games, configuration: ScoresConfiguration(varsityOnly: false), now: WidgetGallery.now)
    }

    private static func upcoming(_ meal: Meal, on date: LocalDate, _ menu: DailyMenu) -> UpcomingMenu {
        UpcomingMenu(meal: meal, date: date, menu: menu, validUntil: meal.serviceEnd(on: date))
    }

    private static func dailyMenu(_ meal: Meal, on date: LocalDate, stations: [(title: String, dishes: [String])]) -> DailyMenu {
        var id = 0
        let sections = stations.map { station in
            MenuSection(title: station.title, items: station.dishes.map { name in
                id += 1
                return MenuItem(id: id, name: name)
            })
        }
        return DailyMenu(date: date, meal: meal, sections: sections)
    }
}
