import SwiftUI
import WidgetKit
import NoblesKit

/// The user's designs and school calendar, kept in sync with the app group so widgets see every
/// change. Edits save after a short pause, so typing a name doesn't reload widgets per keystroke,
/// and each save reloads only the widgets whose designs or dates changed.
@MainActor @Observable
final class DesignLibrary {
    private(set) var designs: [WidgetDesign]
    private(set) var calendar: SchoolCalendar
    private(set) var hasCustomCalendar: Bool

    private let store: DesignStore
    @ObservationIgnored private var pendingDesignSave: Task<Void, Never>?
    @ObservationIgnored private var pendingCalendarSave: Task<Void, Never>?
    /// Kinds whose designs changed since the last save; their widgets reload when it happens.
    @ObservationIgnored private var changedKinds: Set<WidgetKind> = []

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
        saveDesigns(changing: kind)
        return design
    }

    /// Replaces the design with the same ID. Saved after a short pause.
    func update(_ design: WidgetDesign) {
        guard let index = designs.firstIndex(where: { $0.id == design.id }), designs[index] != design else { return }
        changedKinds.formUnion([designs[index].kind, design.kind])
        designs[index] = design
        scheduleDesignSave()
    }

    func delete(id: UUID) {
        guard let design = design(id: id) else { return }
        designs.removeAll { $0.id == id }
        saveDesigns(changing: design.kind)
    }

    /// Deletes rows of one kind's section in the design list.
    func delete(_ kind: WidgetKind, at offsets: IndexSet) {
        let section = designs(of: kind)
        let ids = Set(offsets.map { section[$0].id })
        designs.removeAll { ids.contains($0.id) }
        saveDesigns(changing: kind)
    }

    /// Reorders rows within one kind's section in the design list. The first design of a kind is
    /// the one widgets show when none is picked, so this reloads that kind's widgets too.
    func move(_ kind: WidgetKind, from source: IndexSet, to destination: Int) {
        var section = designs(of: kind)
        section.move(fromOffsets: source, toOffset: destination)
        designs = WidgetKind.allCases.flatMap { $0 == kind ? section : designs(of: $0) }
        saveDesigns(changing: kind)
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

    /// Goes back to the built-in calendar, dropping any edit still waiting to be saved.
    func resetCalendar() {
        pendingCalendarSave?.cancel()
        pendingCalendarSave = nil
        store.saveCalendar(nil)
        calendar = store.calendar()
        hasCustomCalendar = false
        reloadWidgets(of: .countdown)
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

    /// Saves now, with `kind` among the kinds whose widgets reload.
    private func saveDesigns(changing kind: WidgetKind) {
        changedKinds.insert(kind)
        saveDesigns()
    }

    private func saveDesigns() {
        pendingDesignSave?.cancel()
        pendingDesignSave = nil
        store.save(designs)
        for kind in changedKinds {
            reloadWidgets(of: kind)
        }
        changedKinds = []
    }

    private func saveCalendar() {
        pendingCalendarSave?.cancel()
        pendingCalendarSave = nil
        store.saveCalendar(calendar)
        reloadWidgets(of: .countdown)
    }

    private func reloadWidgets(of kind: WidgetKind) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind.timelineKind)
    }
}
