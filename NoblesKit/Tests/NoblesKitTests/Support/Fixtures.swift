import Foundation
import Testing
@testable import NoblesKit

enum Fixture {
    /// The contents of `Fixtures/<name>`.
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

extension LocalDate {
    init(_ year: Int, _ month: Int, _ day: Int) {
        self.init(year: year, month: month, day: day)
    }
}

/// A fresh path in the temporary directory; the caller removes it.
func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "NoblesKitTests-\(UUID().uuidString)", directoryHint: .isDirectory)
}

/// Menu responses for tests: the real captured week of 2026-10-25 and generated weeks around it.
enum MenuFixtures {
    static let endpoint = MenuEndpoint.nobles
    /// The Monday of the captured week.
    static let capturedMonday = LocalDate(2026, 10, 26)
    static let nextMonday = LocalDate(2026, 11, 2)

    static func weekURL(_ meal: Meal, monday: LocalDate) -> URL {
        endpoint.weekURL(menuType: meal.rawValue, date: monday)
    }

    /// The schools list plus the captured lunch and dinner weeks.
    static func realResponses() throws -> [URL: FakeHTTPClient.Response] {
        [
            endpoint.schoolsURL: .data(try Fixture.data("real-schools.json")),
            weekURL(.lunch, monday: capturedMonday): .data(try Fixture.data("real-lunch-week.json")),
            weekURL(.dinner, monday: capturedMonday): .data(try Fixture.data("real-dinner-week.json")),
        ]
    }

    /// The real menu for `meal` on `date`, decoded through `MenuService`.
    static func realMenu(_ meal: Meal, on date: LocalDate) async throws -> DailyMenu {
        let service = MenuService(http: FakeHTTPClient(try realResponses()), cache: nil)
        let week = try await service.week(containing: date, meal: meal)
        return try #require(week.first { $0.date == date })
    }

    /// A week response in Nobles' real shape (text-only dishes under station headers) for the
    /// Sunday–Saturday week containing `monday`, with one "Hot Entree" dish on each listed day.
    static func week(monday: LocalDate, dishes: [LocalDate: String] = [:]) throws -> Data {
        var nextID = 1
        func row(_ text: String, position: Int, isHeader: Bool) -> [String: Any] {
            defer { nextID += 1 }
            return [
                "id": nextID, "date": NSNull(), "position": position, "text": text, "category": "",
                "is_section_title": isHeader, "is_station_header": isHeader, "is_holiday": false, "food": NSNull(),
            ]
        }
        var days: [[String: Any]] = []
        for offset in -1...5 {
            let date = monday.adding(days: offset)
            var items: [[String: Any]] = []
            if let dish = dishes[date] {
                items = [row("Hot Entree", position: 0, isHeader: true), row(dish, position: 1, isHeader: false)]
            }
            days.append(["date": date.iso, "has_unpublished_menus": false, "menu_info": [String: Any](), "menu_items": items])
        }
        return try JSONSerialization.data(withJSONObject: ["start_date": monday.iso, "menu_type_id": 1, "days": days])
    }
}
