import SwiftUI
import WidgetKit
import NoblesKit

/// Draws widget content as the Home Screen or Lock Screen would: at the family's real point size
/// (as on a large iPhone), with the system's content margins, background and corner radius.
struct WidgetPreviewFrame<Content: View>: View {
    let family: WidgetFamily
    let theme: Theme
    /// The widget's content, given the theme's colors as resolved for this family and appearance.
    @ViewBuilder let content: (ThemeColors) -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = ThemeColors(theme: theme, colorScheme: colorScheme, family: family)
        let themed = content(colors).widgetTheme(theme, colors: colors)
        if family.isAccessory {
            lockScreen(themed)
        } else {
            homeScreen(themed, colors: colors)
        }
    }

    private func homeScreen(_ widget: some View, colors: ThemeColors) -> some View {
        let size = family.widgetPointSize
        return widget
            .padding(PreviewMetrics.contentMargin)
            .frame(width: size.width, height: size.height)
            .background { WidgetBackground(theme: theme, colors: colors) }
            .clipShape(RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    /// Lock Screen widgets are monochrome over the wallpaper, so they sit on a dark backdrop here.
    /// Circular ones get a translucent disc like the `AccessoryWidgetBackground` the widget draws,
    /// which only renders inside a widget.
    private func lockScreen(_ widget: some View) -> some View {
        let size = family.widgetPointSize
        return widget
            .lineLimit(family == .accessoryInline ? 1 : nil)
            .frame(width: size.width, height: size.height)
            .background {
                if family == .accessoryCircular {
                    Circle().fill(Color.white.opacity(0.16))
                }
            }
            .environment(\.colorScheme, .dark)
            .padding(PreviewMetrics.lockScreenInset)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x33415C), Color(hex: 0x141B2D)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius, style: .continuous)
            )
    }
}

/// Shows a preview at its natural size, shrunk uniformly when the space offered is smaller.
struct FittedPreview<Content: View>: View {
    let size: CGSize
    let content: Content

    init(size: CGSize, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.width / size.width, proxy.size.height / size.height)
            content
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private enum PreviewMetrics {
    static let contentMargin: CGFloat = 16
    static let cornerRadius: CGFloat = 22
    static let lockScreenInset: CGFloat = 22
}

extension WidgetFamily {
    /// e.g. "Small", "Lock Screen · Circular".
    var previewName: String {
        switch self {
        case .systemSmall: "Small"
        case .systemMedium: "Medium"
        case .systemLarge: "Large"
        case .systemExtraLarge: "Extra Large"
        case .accessoryCircular: "Lock Screen · Circular"
        case .accessoryRectangular: "Lock Screen · Rectangular"
        case .accessoryInline: "Lock Screen · Inline"
        default: "Widget"
        }
    }

    /// The widget's size in points on a large iPhone.
    var widgetPointSize: CGSize {
        switch self {
        case .systemSmall: CGSize(width: 170, height: 170)
        case .systemMedium: CGSize(width: 364, height: 170)
        case .accessoryCircular: CGSize(width: 76, height: 76)
        case .accessoryRectangular: CGSize(width: 172, height: 76)
        case .accessoryInline: CGSize(width: 240, height: 22)
        default: CGSize(width: 364, height: 382)
        }
    }

    /// The whole preview, including the backdrop drawn around Lock Screen widgets.
    var previewSize: CGSize {
        let size = widgetPointSize
        guard isAccessory else { return size }
        let inset = 2 * PreviewMetrics.lockScreenInset
        return CGSize(width: size.width + inset, height: size.height + inset)
    }
}
