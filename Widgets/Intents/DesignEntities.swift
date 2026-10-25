import AppIntents
import NoblesKit

/// A saved design, as offered in a widget's "Edit Widget" sheet.
///
/// There's one concrete entity per widget kind, so each widget lists only its own designs. App
/// Intents metadata is extracted per type at build time, so these can't be one generic type; the
/// shared behavior lives in protocol extensions instead.
protocol DesignEntity: AppEntity where ID == UUID {
    static var kind: WidgetKind { get }
    var id: UUID { get }
    var name: String { get }
    init(id: UUID, name: String)
}

extension DesignEntity {
    init(_ design: WidgetDesign) {
        self.init(id: design.id, name: design.name)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name.isEmpty ? "Untitled" : name)",
            image: DisplayRepresentation.Image(systemName: Self.kind.symbolName)
        )
    }
}

/// Finds designs of the entity's kind in the app group, where the app saves them.
protocol DesignEntityQuery: EntityQuery where Entity: DesignEntity {}

extension DesignEntityQuery {
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity] {
        let designs = DesignStore().designs(of: Entity.kind)
        return identifiers.compactMap { id in
            designs.first { $0.id == id }.map { Entity($0) }
        }
    }

    func suggestedEntities() async throws -> [Entity] {
        DesignStore().designs(of: Entity.kind).map { Entity($0) }
    }

    /// The first design of this kind, so a newly added widget shows something sensible.
    func defaultResult() async -> Entity? {
        DesignStore().designs(of: Entity.kind).first.map { Entity($0) }
    }
}

// MARK: - Menu

struct MenuDesignEntity: DesignEntity {
    static let kind = WidgetKind.menu
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Menu Design") }
    static var defaultQuery: MenuDesignQuery { MenuDesignQuery() }

    let id: UUID
    let name: String
}

struct MenuDesignQuery: DesignEntityQuery {
    typealias Entity = MenuDesignEntity
}

// MARK: - Countdown

struct CountdownDesignEntity: DesignEntity {
    static let kind = WidgetKind.countdown
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Countdown Design") }
    static var defaultQuery: CountdownDesignQuery { CountdownDesignQuery() }

    let id: UUID
    let name: String
}

struct CountdownDesignQuery: DesignEntityQuery {
    typealias Entity = CountdownDesignEntity
}

// MARK: - Scores

struct ScoresDesignEntity: DesignEntity {
    static let kind = WidgetKind.scores
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Scores Design") }
    static var defaultQuery: ScoresDesignQuery { ScoresDesignQuery() }

    let id: UUID
    let name: String
}

struct ScoresDesignQuery: DesignEntityQuery {
    typealias Entity = ScoresDesignEntity
}
