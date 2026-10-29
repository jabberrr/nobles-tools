import SwiftUI
import WidgetKit
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

extension View {
    /// Fills the widget, then draws `disc` behind it on the circular Lock Screen size, so the disc
    /// spans the whole circle rather than hugging the content. The widget passes the system's
    /// `AccessoryWidgetBackground`; the app's previews, where that draws nothing, a stand-in.
    func circularBackdrop<Disc: View>(for family: WidgetFamily, @ViewBuilder disc: () -> Disc) -> some View {
        let disc = disc()
        return frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if family == .accessoryCircular {
                    disc
                }
            }
    }
}
