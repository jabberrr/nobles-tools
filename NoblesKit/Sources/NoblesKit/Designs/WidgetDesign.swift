import Foundation

/// The three widget families Nobles Tools offers. Each maps to one WidgetKit widget.
public enum WidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case menu
    case countdown
    case scores

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .menu: "Dining Menu"
        case .countdown: "Countdown"
        case .scores: "Scores"
        }
    }

    public var summary: String {
        switch self {
        case .menu: "Lunch, dinner or the next meal, from the dining hall."
        case .countdown: "Days left in the quarter, semester or year."
        case .scores: "Recent results and upcoming games."
        }
    }

    /// SF Symbol used for this kind throughout the app.
    public var symbolName: String {
        switch self {
        case .menu: "fork.knife"
        case .countdown: "calendar.badge.clock"
        case .scores: "sportscourt"
        }
    }
}

/// A user-created widget: what it shows and how it looks. Designs are made in the app
/// and picked from the widget's "Edit Widget" sheet on the Home Screen.
public struct WidgetDesign: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var theme: Theme
    public var content: WidgetContent

    public init(id: UUID = UUID(), name: String, theme: Theme = .init(), content: WidgetContent) {
        self.id = id
        self.name = name
        self.theme = theme
        self.content = content
    }

    /// `id` and `content` are required, since nothing could stand in for them. Other missing
    /// fields take defaults, so designs saved by other versions still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(WidgetContent.self, forKey: .content)
        name = container.decode(.name, or: content.kind.displayName)
        theme = container.decode(.theme, or: Theme())
    }

    public var kind: WidgetKind { content.kind }

    /// A sensible starting point for a new design of `kind`.
    public static func makeDefault(_ kind: WidgetKind) -> WidgetDesign {
        switch kind {
        case .menu: WidgetDesign(name: "Lunch", content: .menu(MenuConfiguration()))
        case .countdown: WidgetDesign(name: "Year Countdown", content: .countdown(CountdownConfiguration()))
        case .scores: WidgetDesign(name: "Scores", content: .scores(ScoresConfiguration()))
        }
    }
}

/// Kind-specific settings for a design.
public enum WidgetContent: Codable, Hashable, Sendable {
    case menu(MenuConfiguration)
    case countdown(CountdownConfiguration)
    case scores(ScoresConfiguration)

    public var kind: WidgetKind {
        switch self {
        case .menu: .menu
        case .countdown: .countdown
        case .scores: .scores
        }
    }
}

// MARK: - Appearance

/// Visual styling shared by every widget kind.
public struct Theme: Codable, Hashable, Sendable {
    public var palette: Palette
    public var font: FontStyle
    public var background: BackgroundStyle

    public init(palette: Palette = .classic, font: FontStyle = .standard, background: BackgroundStyle = .gradient) {
        self.palette = palette
        self.font = font
        self.background = background
    }

    /// Missing fields take their defaults, so themes saved by other versions still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Theme()
        palette = container.decode(.palette, or: defaults.palette)
        font = container.decode(.font, or: defaults.font)
        background = container.decode(.background, or: defaults.background)
    }
}

/// Named color schemes. Colors are stored as hex so this module stays UI-framework-free;
/// the app and widgets convert them to SwiftUI colors.
public enum Palette: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Follows the system light/dark appearance.
    case classic
    case navy
    case crimson
    case forest
    case sunset
    case graphite
    case paper

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .classic: "Classic"
        case .navy: "Navy"
        case .crimson: "Crimson"
        case .forest: "Forest"
        case .sunset: "Sunset"
        case .graphite: "Graphite"
        case .paper: "Paper"
        }
    }

    /// `nil` for `.classic`, which uses system colors instead of fixed ones. Text colors keep a
    /// contrast of at least 4.5:1, and the accent 3:1, against both ends of the background.
    public var colors: PaletteColors? {
        switch self {
        case .classic: nil
        case .navy: PaletteColors(background: 0x0B2545, backgroundEnd: 0x13315C, primary: 0xFFFFFF, secondary: 0xB8C7DC, accent: 0x8DB3F2)
        case .crimson: PaletteColors(background: 0x7A0E1F, backgroundEnd: 0xA4161A, primary: 0xFFFFFF, secondary: 0xF2C6CB, accent: 0xFFD166)
        case .forest: PaletteColors(background: 0x1B4332, backgroundEnd: 0x2D6A4F, primary: 0xFFFFFF, secondary: 0xB7E4C7, accent: 0xFFE66D)
        case .sunset: PaletteColors(background: 0xC2334D, backgroundEnd: 0xB54516, primary: 0xFFFFFF, secondary: 0xFFEDE0, accent: 0xFFE08A)
        case .graphite: PaletteColors(background: 0x1C1C1E, backgroundEnd: 0x2C2C2E, primary: 0xF2F2F7, secondary: 0x98989D, accent: 0x64D2FF)
        case .paper: PaletteColors(background: 0xFAF7F0, backgroundEnd: 0xF1EBDD, primary: 0x1F1F1F, secondary: 0x6B6459, accent: 0xB0413E)
        }
    }
}

/// Fixed colors as 0xRRGGBB values.
public struct PaletteColors: Hashable, Sendable {
    public var background: UInt32
    public var backgroundEnd: UInt32
    public var primary: UInt32
    public var secondary: UInt32
    public var accent: UInt32
}

public enum FontStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case rounded
    case serif
    case monospaced

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: "Standard"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .monospaced: "Mono"
        }
    }
}

public enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case solid
    case gradient

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .solid: "Solid"
        case .gradient: "Gradient"
        }
    }
}
