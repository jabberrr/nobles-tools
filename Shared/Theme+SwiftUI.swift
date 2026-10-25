import SwiftUI
import WidgetKit
import NoblesKit

extension Color {
    /// An opaque sRGB color from a `0xRRGGBB` value.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// A theme's colors resolved for one rendering context.
struct ThemeColors {
    var background: Color
    var backgroundEnd: Color
    var primary: Color
    var secondary: Color
    var accent: Color
    /// Text drawn on an `accent` fill, such as a win badge.
    var onAccent: Color

    /// Colors for `theme` as it appears in `family`.
    ///
    /// `.classic` follows `colorScheme`; the other palettes are fixed. Lock Screen widgets, and
    /// widgets whose background the system has removed (StandBy, the iPad Lock Screen), use plain
    /// system colors instead, because the system renders them over its own backdrop.
    init(theme: Theme, colorScheme: ColorScheme, family: WidgetFamily, showsBackground: Bool = true) {
        if family.isAccessory || !showsBackground {
            self.init(background: .clear, backgroundEnd: .clear, primary: .primary, secondary: .secondary, accent: .primary, onAccent: .black)
        } else if let colors = theme.palette.colors {
            self.init(
                background: Color(hex: colors.background),
                backgroundEnd: Color(hex: colors.backgroundEnd),
                primary: Color(hex: colors.primary),
                secondary: Color(hex: colors.secondary),
                accent: Color(hex: colors.accent),
                onAccent: Color(hex: colors.background)
            )
        } else if colorScheme == .dark {
            self.init(
                background: Color(hex: 0x1C1C1E),
                backgroundEnd: Color(hex: 0x2A2D34),
                primary: .primary,
                secondary: .secondary,
                accent: Color(hex: 0x7EB0F7),
                onAccent: Color(hex: 0x1C1C1E)
            )
        } else {
            self.init(
                background: .white,
                backgroundEnd: Color(hex: 0xEDF1F7),
                primary: .primary,
                secondary: .secondary,
                accent: Color(hex: 0x1D4E89),
                onAccent: .white
            )
        }
    }

    private init(background: Color, backgroundEnd: Color, primary: Color, secondary: Color, accent: Color, onAccent: Color) {
        self.background = background
        self.backgroundEnd = backgroundEnd
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.onAccent = onAccent
    }

    /// A faint version of the primary color, for progress tracks and dividers.
    var track: Color { primary.opacity(0.15) }
}

extension FontStyle {
    var fontDesign: Font.Design {
        switch self {
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        }
    }
}

extension WidgetFamily {
    /// Lock Screen families, which render monochrome over the wallpaper.
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: true
        default: false
        }
    }
}
