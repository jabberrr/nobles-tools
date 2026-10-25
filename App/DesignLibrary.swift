import SwiftUI
import WidgetKit
import NoblesKit

/// The user's designs and school calendar, kept in sync with the app group so widgets see every
/// change. Edits save after a short pause, so typing a name doesn't reload widgets per keystroke.
@MainActor @Observable
final class DesignLibrary {
    private(set) var designs: [WidgetDesign]
    private(set) var calendar: SchoolCalendar
    private(set) var hasCustomCalendar: Bool

    private let store: DesignStore
    @ObservationIgnored private var pendingDesignSave: Task<Void, Never>?
    @ObservationIgnored private var pendingCalendarSave: Task<Void, Never>?

    private static let saveDelay = Duration.milliseconds(500)

    init(store: DesignStore = DesignStore()) {
        self.store = store
        designs = store.designs()
        calendar = store.calendar()
        hasCustomCalendar = store.hasCustomCalendar
    }

    // MARK: Designs

    func designs(of kind: WidgetKind) -> [WidgetDesign] {
        designs.filter { $0.kind == kind }
    }

    func design(id: UUID) -> WidgetDesign? {
        designs.first { $0.id == id }
    }

    /// Adds a new design of `kind` with a name not already in use, and returns it.
    @discardableResult
    func add(_ kind: WidgetKind) -> WidgetDesign {
        var design = WidgetDesign.makeDefault(kind)
        design.name = uniqueName(for: design.name)
        designs.append(design)
        saveDesigns()
        return design
    }

    /// Replaces the design with the same ID. Saved after a short pause.
    func update(_ design: WidgetDesign) {
        guard let index = designs.firstIndex(where: { $0.id == design.id }), designs[index] != design else { return }
        designs[index] = design
        scheduleDesignSave()
    }

    func delete(id: UUID) {
        designs.removeAll { $0.id == id }
        saveDesigns()
    }

    /// Deletes rows of one kind's section in the design list.
    func delete(_ kind: WidgetKind, at offsets: IndexSet) {
        let section = designs(of: kind)
        let ids = Set(offsets.map { section[$0].id })
        designs.removeAll { ids.contains($0.id) }
        saveDesigns()
    }

    /// Reorders rows within one kind's section in the design list.
    func move(_ kind: WidgetKind, from source: IndexSet, to destination: Int) {
        var section = designs(of: kind)
        section.move(fromOffsets: source, toOffset: destination)
        designs = WidgetKind.allCases.flatMap { $0 == kind ? section : designs(of: $0) }
        saveDesigns()
    }

    private func uniqueName(for base: String) -> String {
        let names = Set(designs.map(\.name))
        guard names.contains(base) else { return base }
        var number = 2
        while names.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    // MARK: Calendar

    /// Replaces the school calendar with an edited one. Saved after a short pause.
    func updateCalendar(_ calendar: SchoolCalendar) {
        guard calendar != self.calendar else { return }
        self.calendar = calendar
        hasCustomCalendar = true
        pendingCalendarSave?.cancel()
        pendingCalendarSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveCalendar()
        }
    }

    /// Goes back to the built-in calendar.
    func resetCalendar() {
        pendingCalendarSave?.cancel()
        store.saveCalendar(nil)
        calendar = store.calendar()
        hasCustomCalendar = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Saving

    /// Writes any edits still waiting out the save delay, e.g. when the app moves to the background.
    func saveNow() {
        if pendingDesignSave != nil { saveDesigns() }
        if pendingCalendarSave != nil { saveCalendar() }
    }

    private func scheduleDesignSave() {
        pendingDesignSave?.cancel()
        pendingDesignSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveDesigns()
        }
    }

    private func saveDesigns() {
        pendingDesignSave?.cancel()
        pendingDesignSave = nil
        store.save(designs)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveCalendar() {
        pendingCalendarSave?.cancel()
        pendingCalendarSave = nil
        store.saveCalendar(calendar)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
