import SwiftUI
import NoblesKit

/// The themed fill behind a widget, in colors already resolved for where it's drawn. Lock Screen
/// colors have a clear background, since the system draws those widgets over the wallpaper.
///
/// The widget extension installs it with `containerBackground(for: .widget)`; the app draws it
/// directly behind its previews, since container backgrounds only take effect inside widgets.
struct WidgetBackground: View {
    let theme: Theme
    let colors: ThemeColors

    var body: some View {
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
