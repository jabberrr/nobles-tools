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

/// What every Nobles Tools widget shares: the design's themed container background, and a tap
/// target that opens the design in the app's editor.
struct WidgetChrome<Content: View>: View {
    let design: WidgetDesign
    @ViewBuilder let content: (WidgetFamily) -> Content

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content(family)
            .containerBackground(for: .widget) {
                WidgetBackground(theme: design.theme, family: family)
            }
            .widgetURL(DeepLink.url(for: design.id))
    }
}
