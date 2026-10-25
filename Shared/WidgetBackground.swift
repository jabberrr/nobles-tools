import SwiftUI
import WidgetKit
import NoblesKit

/// The themed fill behind a widget.
///
/// The widget extension installs it with `containerBackground(for: .widget)`; the app draws it
/// directly behind its previews, since container backgrounds only take effect inside widgets.
/// Lock Screen families get no fill: the system draws them over the wallpaper.
struct WidgetBackground: View {
    let theme: Theme
    let family: WidgetFamily

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if family.isAccessory {
            Color.clear
        } else {
            let colors = ThemeColors(theme: theme, colorScheme: colorScheme, family: family)
            switch theme.background {
            case .solid:
                colors.background
            case .gradient:
                LinearGradient(
                    colors: [colors.background, colors.backgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
