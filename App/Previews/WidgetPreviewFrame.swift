import SwiftUI
import WidgetKit
import NoblesKit

/// Draws widget content as the Home Screen or Lock Screen would: at the family's real point size
/// on `screen`, with the system's content margins, background and corner radius.
struct WidgetPreviewFrame<Content: View>: View {
    let family: WidgetFamily
    let theme: Theme
    var screen = PreviewScreen.large
    /// Draws the Home Screen's tinted (or clear) mode instead of full color.
    var isTinted = false
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
        let size = family.pointSize(on: screen)
        let framed = widget
            .padding(PreviewMetrics.contentMargin)
            .frame(width: size.width, height: size.height)
        return Group {
            if isTinted {
                // The tinted and clear modes keep only the shape (alpha) of each view, drawing it
                // in a single color over the system's glass.
                framed
                    .colorMultiply(.black)
                    .colorInvert()
                    .background(Color(hex: 0x46566B))
            } else {
                framed.background { WidgetBackground(theme: theme, colors: colors) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    /// Lock Screen widgets are monochrome over the wallpaper, so they sit on a dark backdrop here.
    /// Circular ones get a translucent disc standing in for the `AccessoryWidgetBackground` the
    /// widget draws, which only renders inside a widget; it's laid out the same way as the widget's.
    private func lockScreen(_ widget: some View) -> some View {
        let size = family.pointSize(on: screen)
        return widget
            .lineLimit(family == .accessoryInline ? 1 : nil)
            .circularBackdrop(for: family) {
                Circle().fill(Color.white.opacity(0.16))
            }
            .frame(width: size.width, height: size.height)
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

/// The iPhone size a preview is drawn for.
enum PreviewScreen {
    /// A large iPhone, such as a Pro Max.
    case large
    /// A 6.1-inch iPhone, whose widgets are a little smaller.
    case compact
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

    /// The widget's size in points on `screen`.
    func pointSize(on screen: PreviewScreen) -> CGSize {
        switch (self, screen) {
        case (.systemSmall, .large): CGSize(width: 170, height: 170)
        case (.systemSmall, .compact): CGSize(width: 158, height: 158)
        case (.systemMedium, .large): CGSize(width: 364, height: 170)
        case (.systemMedium, .compact): CGSize(width: 338, height: 158)
        case (.accessoryCircular, .large): CGSize(width: 76, height: 76)
        case (.accessoryCircular, .compact): CGSize(width: 72, height: 72)
        case (.accessoryRectangular, .large): CGSize(width: 172, height: 76)
        case (.accessoryRectangular, .compact): CGSize(width: 160, height: 72)
        case (.accessoryInline, .large): CGSize(width: 240, height: 22)
        case (.accessoryInline, .compact): CGSize(width: 220, height: 22)
        case (_, .large): CGSize(width: 364, height: 382)
        case (_, .compact): CGSize(width: 338, height: 354)
        }
    }

    /// The whole preview on a large iPhone, including the backdrop drawn around Lock Screen widgets.
    var previewSize: CGSize {
        let size = pointSize(on: .large)
        guard isAccessory else { return size }
        let inset = 2 * PreviewMetrics.lockScreenInset
        return CGSize(width: size.width + inset, height: size.height + inset)
    }
}
