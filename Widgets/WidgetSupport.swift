import SwiftUI
import WidgetKit
import NoblesKit

extension DesignStore {
    /// The design a widget shows: the one picked in Edit Widget, or, if none was picked or it has
    /// since been deleted, the first design of that kind, or else a default one.
    func resolvedDesign(id: UUID?, kind: WidgetKind) -> WidgetDesign {
        let saved = designs(of: kind)
        return saved.first { $0.id == id } ?? saved.first ?? .makeDefault(kind)
    }
}

/// What every Nobles Tools widget shares: the design's theme resolved for where the widget is
/// shown (passed to `content` with the family), its themed container background, and a tap
/// target that opens the design in the app's editor.
struct WidgetChrome<Content: View>: View {
    let design: WidgetDesign
    @ViewBuilder let content: (WidgetFamily, ThemeColors) -> Content

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        let colors = ThemeColors(theme: design.theme, colorScheme: colorScheme, family: family, showsBackground: showsBackground)
        content(family, colors)
            .widgetTheme(design.theme, colors: colors)
            .containerBackground(for: .widget) {
                WidgetBackground(theme: design.theme, colors: colors)
            }
            .widgetURL(DeepLink.url(for: design.id))
    }
}
