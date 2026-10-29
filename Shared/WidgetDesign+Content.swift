import WidgetKit
import NoblesKit

extension WidgetDesign {
    /// The menu settings, or `nil` for other kinds. Assigning a value makes this a menu design.
    var menuConfiguration: MenuConfiguration? {
        get {
            guard case .menu(let configuration) = content else { return nil }
            return configuration
        }
        set {
            if let newValue { content = .menu(newValue) }
        }
    }

    /// The countdown settings, or `nil` for other kinds. Assigning a value makes this a countdown design.
    var countdownConfiguration: CountdownConfiguration? {
        get {
            guard case .countdown(let configuration) = content else { return nil }
            return configuration
        }
        set {
            if let newValue { content = .countdown(newValue) }
        }
    }

    /// The scores settings, or `nil` for other kinds. Assigning a value makes this a scores design.
    var scoresConfiguration: ScoresConfiguration? {
        get {
            guard case .scores(let configuration) = content else { return nil }
            return configuration
        }
        set {
            if let newValue { content = .scores(newValue) }
        }
    }
}

extension WidgetKind {
    /// The sizes each kind's widget offers, in the order the editor previews them: every Home
    /// Screen and Lock Screen size.
    var widgetFamilies: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
    }

    /// The WidgetKit `kind` of this kind's widget, which it's configured and reloaded by.
    var timelineKind: String {
        switch self {
        case .menu: "MenuWidget"
        case .countdown: "CountdownWidget"
        case .scores: "ScoresWidget"
        }
    }
}
