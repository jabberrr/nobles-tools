import Foundation

/// Saves widget designs and the school calendar as JSON in the app group's defaults, so the app
/// and its widgets see the same data. Unreadable data counts as missing rather than crashing,
/// and designs are read one by one, so a design that can't be read doesn't hide the others.
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

    /// Every saved design that can be read, in the user's order.
    public func designs() -> [WidgetDesign] {
        decode([Lossy<WidgetDesign>].self, forKey: Key.designs)?.compactMap(\.value) ?? []
    }

    public func designs(of kind: WidgetKind) -> [WidgetDesign] {
        designs().filter { $0.kind == kind }
    }

    /// Replaces every saved design.
    public func save(_ designs: [WidgetDesign]) {
        encode(designs, forKey: Key.designs)
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
