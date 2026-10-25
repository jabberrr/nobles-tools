import AppIntents
import WidgetKit

/// "Edit Widget" options for the Dining Menu widget.
struct MenuWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Dining Menu" }
    static var description: IntentDescription { IntentDescription("Shows one of your dining menu designs.") }

    @Parameter(title: "Design")
    var design: MenuDesignEntity?
}

/// "Edit Widget" options for the Countdown widget.
struct CountdownWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Countdown" }
    static var description: IntentDescription { IntentDescription("Shows one of your countdown designs.") }

    @Parameter(title: "Design")
    var design: CountdownDesignEntity?
}

/// "Edit Widget" options for the Scores widget.
struct ScoresWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Scores" }
    static var description: IntentDescription { IntentDescription("Shows one of your scores designs.") }

    @Parameter(title: "Design")
    var design: ScoresDesignEntity?
}
