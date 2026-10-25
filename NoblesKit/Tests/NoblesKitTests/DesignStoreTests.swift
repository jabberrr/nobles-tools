import Foundation
import Testing
@testable import NoblesKit

struct DesignStoreTests {
    /// Runs `body` with a store in a fresh defaults suite, removed afterwards.
    private func withStore(_ body: (DesignStore, UserDefaults) throws -> Void) throws {
        let suiteName = "NoblesKitTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(DesignStore(suiteName: suiteName), defaults)
    }

    @Test func savesDesignsInOrder() throws {
        try withStore { store, _ in
            #expect(store.designs().isEmpty)
            let lunch = WidgetDesign.makeDefault(.menu)
            var countdown = WidgetDesign.makeDefault(.countdown)
            let scores = WidgetDesign.makeDefault(.scores)
            store.save([lunch, countdown, scores])
            #expect(store.designs() == [lunch, countdown, scores])
            #expect(store.designs(of: .countdown) == [countdown])

            countdown.name = "Summer"
            store.save([countdown, lunch])
            #expect(store.designs() == [countdown, lunch])
        }
    }

    @Test func seedsDefaultsOnlyOnce() throws {
        try withStore { store, _ in
            store.seedDefaultsIfNeeded()
            #expect(store.designs().map(\.kind) == WidgetKind.allCases)

            store.save([])
            store.seedDefaultsIfNeeded()
            #expect(store.designs().isEmpty)
        }
    }

    @Test func seedingKeepsExistingDesigns() throws {
        try withStore { store, _ in
            let design = WidgetDesign(name: "Dinner", content: .menu(MenuConfiguration(meal: .dinner)))
            store.save([design])
            store.seedDefaultsIfNeeded()
            #expect(store.designs() == [design])
        }
    }

    @Test func savesACustomCalendar() throws {
        try withStore { store, _ in
            #expect(store.calendar() == .nobles2026_27)
            #expect(!store.hasCustomCalendar)

            var custom = SchoolCalendar.nobles2026_27
            custom.breaks.append(SchoolBreak(name: "Snow Day", span: DateSpan(start: LocalDate(2027, 2, 2), end: LocalDate(2027, 2, 2))))
            store.saveCalendar(custom)
            #expect(store.calendar() == custom)
            #expect(store.hasCustomCalendar)

            store.saveCalendar(nil)
            #expect(store.calendar() == .nobles2026_27)
            #expect(!store.hasCustomCalendar)
        }
    }

    @Test func skipsDesignsThatCannotBeRead() throws {
        try withStore { store, defaults in
            let lunch = WidgetDesign.makeDefault(.menu)
            let scores = WidgetDesign.makeDefault(.scores)
            let lunchJSON = String(decoding: try JSONEncoder().encode(lunch), as: UTF8.self)
            let scoresJSON = String(decoding: try JSONEncoder().encode(scores), as: UTF8.self)
            let saved = #"[\#(lunchJSON), {"id": "not-a-uuid", "name": "Broken"}, 42, \#(scoresJSON)]"#
            defaults.set(Data(saved.utf8), forKey: "designs.v1")

            #expect(store.designs() == [lunch, scores])
        }
    }

    @Test func readsDesignsSavedByEarlierVersions() throws {
        try withStore { store, defaults in
            // Saved when menus had a descriptions toggle; the old key is ignored.
            let saved = #"""
            [{"id": "6F1C4A39-2D0B-4B8E-9F4E-1D2C3B4A5E6F", "name": "Entrées",
              "theme": {"palette": "navy", "font": "rounded", "background": "solid"},
              "content": {"menu": {"_0": {"meal": "upcoming", "filter": {"entreesOnly": {}},
                                          "showsDescriptions": true, "showsSectionHeaders": false}}}}]
            """#
            defaults.set(Data(saved.utf8), forKey: "designs.v1")
            let id = try #require(UUID(uuidString: "6F1C4A39-2D0B-4B8E-9F4E-1D2C3B4A5E6F"))

            #expect(store.designs() == [WidgetDesign(
                id: id,
                name: "Entrées",
                theme: Theme(palette: .navy, font: .rounded, background: .solid),
                content: .menu(MenuConfiguration(meal: .upcoming, filter: .entreesOnly, showsSectionHeaders: false))
            )])
        }
    }

    @Test func unreadableDataCountsAsMissing() throws {
        try withStore { store, defaults in
            defaults.set(Data("not json".utf8), forKey: "designs.v1")
            defaults.set(Data("{}".utf8), forKey: "calendar.v1")

            #expect(store.designs().isEmpty)
            #expect(store.calendar() == .nobles2026_27)
            #expect(!store.hasCustomCalendar)
        }
    }
}
