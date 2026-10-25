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

    @Test func savesUpdatesAndDeletesDesigns() throws {
        try withStore { store, _ in
            #expect(store.designs().isEmpty)
            let lunch = WidgetDesign.makeDefault(.menu)
            var countdown = WidgetDesign.makeDefault(.countdown)
            store.save([lunch, countdown])

            countdown.name = "Summer"
            store.upsert(countdown)
            let scores = WidgetDesign.makeDefault(.scores)
            store.upsert(scores)

            #expect(store.designs() == [lunch, countdown, scores])
            #expect(store.designs(of: .countdown) == [countdown])
            #expect(store.design(id: scores.id) == scores)

            store.delete(id: lunch.id)
            #expect(store.designs() == [countdown, scores])
            #expect(store.design(id: lunch.id) == nil)
        }
    }

    @Test func seedsDefaultsOnlyOnce() throws {
        try withStore { store, _ in
            store.seedDefaultsIfNeeded()
            #expect(store.designs().map(\.kind) == WidgetKind.allCases)

            for design in store.designs() {
                store.delete(id: design.id)
            }
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
