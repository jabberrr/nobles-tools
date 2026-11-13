import SwiftUI

/// Cafe Wrapped's poster look: its type, colors and margins.
///
/// Type is SF Pro throughout: SF Pro Expanded for headlines and big figures, plain SF Pro for
/// everything else. Every font in Wrapped comes from here.
enum WrappedStyle {
    // MARK: Type

    /// Big figures: SF Pro Expanded, bold.
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }

    /// Headlines: SF Pro Expanded, bold.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }

    /// The #1 item's name: SF Pro Expanded, heavy. The one headline set heavier than the rest.
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }

    /// A page's uppercase label (`WrappedEyebrow`), tracked out by `eyebrowTracking`.
    static var eyebrow: Font { .system(size: 14, weight: .semibold) }
    static let eyebrowTracking: CGFloat = 1.4
    /// A stat's small uppercase label (`WrappedLabel`), tracked out by `labelTracking`.
    static var label: Font { .system(size: 11, weight: .semibold) }
    static let labelTracking: CGFloat = 1
    /// The sentence under a headline.
    static var lead: Font { .system(size: 20, weight: .medium) }
    /// An item's name in a row.
    static var itemName: Font { .system(size: 17, weight: .semibold) }
    static var body: Font { .system(size: 17) }
    static var caption: Font { .system(size: 14) }
    /// A caption with a little more weight: counts in rows, chips and the story's header.
    static var strongCaption: Font { .system(size: 14, weight: .medium) }
    /// Labels under a chart's bars and along its axis.
    static var chartLabel: Font { .system(size: 12, weight: .medium) }
    /// Figures over a chart's bars.
    static var chartFigure: Font { .system(size: 13, weight: .semibold) }
    static var button: Font { .system(size: 17, weight: .semibold) }

    /// SF Symbols drawn on their own or beside text.
    static func symbol(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Emoji at `size` points.
    static func emoji(_ size: CGFloat) -> Font {
        .system(size: size)
    }

    /// The design list's banner, which follows Dynamic Type like the list around it.
    static var bannerTitle: Font { .headline.width(.expanded) }
    static var bannerDetail: Font { .subheadline }

    // MARK: Color

    /// A warm yellow for the bar, figure or teaser a page is about: at least 4.5:1 on every page,
    /// and 3:1 on `tileFill` tiles, where it's only used for big figures.
    static var highlight: Color { Color(hex: 0xFDE047) }
    /// Dark text, for the highlight, white buttons and the foil.
    static var ink: Color { Color(hex: 0x1C1530) }
    /// Secondary text: slightly dimmed white, still at least 4.5:1 on every page and on its tiles.
    static var secondary: Color { Color.white.opacity(0.92) }
    /// The fill of the few tiles left (the times of day): faint enough that secondary text on it
    /// keeps 4.5:1.
    static var tileFill: Color { Color.white.opacity(0.10) }

    // MARK: Layout

    /// Every page's side margin.
    static let margin: CGFloat = 24
}

/// A page's small uppercase label, e.g. "WHERE YOU WENT".
struct WrappedEyebrow: View {
    let text: String
    var symbol: String?

    init(_ text: String, symbol: String? = nil) {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text.uppercased())
        }
        .font(WrappedStyle.eyebrow)
        .tracking(WrappedStyle.eyebrowTracking)
        .foregroundStyle(WrappedStyle.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        // VoiceOver reads the label as written, without the symbol's name.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A stat's small uppercase label, e.g. "BIGGEST DAY".
struct WrappedLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(WrappedStyle.label)
            .tracking(WrappedStyle.labelTracking)
            .foregroundStyle(WrappedStyle.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// A big capsule button: white with dark text, or (not prominent) translucent with white text.
struct WrappedButtonStyle: ButtonStyle {
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WrappedStyle.button)
            .lineLimit(1)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isProminent ? WrappedStyle.ink : Color.white)
            .background(isProminent ? Color.white : Color.white.opacity(0.18), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}
