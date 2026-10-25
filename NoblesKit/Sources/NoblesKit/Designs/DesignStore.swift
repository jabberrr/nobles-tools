import Foundation

/// Saves widget designs and the school calendar as JSON in the app group's defaults, so the app
/// and its widgets see the same data. Unreadable data counts as missing rather than crashing.
public struct DesignStore: Sendable {
    private enum Key {
        static let designs = "designs.v1"
        static let seeded = "designs.seeded.v1"
        static let calendar = "calendar.v1"
    }

    private let suiteName: String?

    /// `suiteName` `nil` uses standard defaults.
    public init(suiteName: String? = AppGroup.identifier) {
        self.suiteName = suiteName
    }

    /// Resolved per call: `UserDefaults` isn't `Sendable`, and this keeps the store trivially so.
    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: Designs

    /// Every saved design, in the user's order.
    public func designs() -> [WidgetDesign] {
        decode([WidgetDesign].self, forKey: Key.designs) ?? []
    }

    public func designs(of kind: WidgetKind) -> [WidgetDesign] {
        designs().filter { $0.kind == kind }
    }

    public func design(id: UUID) -> WidgetDesign? {
        designs().first { $0.id == id }
    }

    public func save(_ designs: [WidgetDesign]) {
        encode(designs, forKey: Key.designs)
    }

    /// Replaces the design with the same ID, or appends it.
    public func upsert(_ design: WidgetDesign) {
        var designs = designs()
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            designs[index] = design
        } else {
            designs.append(design)
        }
        save(designs)
    }

    public func delete(id: UUID) {
        save(designs().filter { $0.id != id })
    }

    /// On first launch, adds one default design per kind. Runs once: after the user deletes
    /// every design, they stay deleted.
    public func seedDefaultsIfNeeded() {
        let defaults = defaults
        guard !defaults.bool(forKey: Key.seeded) else { return }
        if designs().isEmpty {
            save(WidgetKind.allCases.map(WidgetDesign.makeDefault))
        }
        defaults.set(true, forKey: Key.seeded)
    }

    // MARK: Calendar

    /// The user's edited calendar, or the built-in estimate.
    public func calendar() -> SchoolCalendar {
        decode(SchoolCalendar.self, forKey: Key.calendar) ?? .nobles2026_27
    }

    /// Saves an edited calendar; `nil` goes back to the built-in one.
    public func saveCalendar(_ calendar: SchoolCalendar?) {
        if let calendar {
            encode(calendar, forKey: Key.calendar)
        } else {
            defaults.removeObject(forKey: Key.calendar)
        }
    }

    public var hasCustomCalendar: Bool {
        decode(SchoolCalendar.self, forKey: Key.calendar) != nil
    }

    // MARK: JSON

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func encode(_ value: some Encodable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
