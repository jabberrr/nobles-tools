import SwiftUI
import NoblesKit

/// Cafe Wrapped's poster look: its type, colors and margins.
enum WrappedStyle {
    /// Big figures: SF Rounded, black.
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    /// Poster headlines: heavy and expanded.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }

    static var eyebrow: Font { .system(size: 15, weight: .heavy, design: .rounded) }
    static var lead: Font { .system(size: 21, weight: .bold, design: .rounded) }
    static var body: Font { .system(size: 18, weight: .semibold, design: .rounded) }
    static var caption: Font { .system(size: 14, weight: .semibold, design: .rounded) }

    /// A warm yellow for the bar, figure or teaser a page is about: at least 4.5:1 on every page.
    static var highlight: Color { Color(hex: 0xFDE047) }
    /// Dark text, for the highlight, white buttons and the foil.
    static var ink: Color { Color(hex: 0x1C1530) }
    /// Secondary text: slightly dimmed white, still at least 4.5:1 on every page.
    static var secondary: Color { Color.white.opacity(0.85) }
    /// The fill of cards and chips.
    static var cardFill: Color { Color.white.opacity(0.13) }

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
        .tracking(1.4)
        .foregroundStyle(WrappedStyle.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// An item's "photo": its emoji on a warm, softly lit plate.
struct WrappedItemPicture: View {
    let emoji: String
    var size: CGFloat = 220

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0xFFF9EF), Color(hex: 0xFFE3BA), Color(hex: 0xF2AE63)],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: size * 0.72
                        )
                    )
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: max(1, size * 0.012))
                    }
                    .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.04)
            }
            .accessibilityHidden(true)
    }
}

/// A figure with a small caption under it, on a card.
struct WrappedStatTile<Figure: View>: View {
    let caption: String
    @ViewBuilder let figure: Figure

    var body: some View {
        VStack(spacing: 4) {
            figure
                .font(WrappedStyle.number(32))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(WrappedStyle.caption)
                .foregroundStyle(WrappedStyle.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(WrappedStyle.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A big capsule button: white with dark text, or (not prominent) translucent with white text.
struct WrappedButtonStyle: ButtonStyle {
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
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

extension View {
    /// Sets content on a frosted card: a translucent white panel with a fine edge.
    func wrappedCard(padding: CGFloat = 16, cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WrappedStyle.cardFill, in: shape)
            .overlay { shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1) }
    }
}

/// Wrapped's figures and dates as text. Dates and times are in school time, whatever the device's
/// time zone.
enum WrappedFormat {
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// "$612.75", for a counting figure.
    static func dollars(_ value: Double) -> String {
        Decimal(value).usd()
    }

    /// A count of whole things as it counts up: "168".
    static func whole(_ value: Double) -> String {
        Int(value.rounded()).formatted()
    }

    /// "1 purchase", "168 purchases".
    static func count(_ count: Int, _ singular: String, plural: String? = nil) -> String {
        let noun = count == 1 ? singular : (plural ?? "\(singular)s")
        return "\(count.formatted()) \(noun)"
    }

    /// "18%".
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// "Fall 2026", or "Fall 2026 · So far" while the semester is still going.
    static func period(_ period: CafeWrapped.Period) -> String {
        period.isComplete ? period.name : "\(period.name) · So far"
    }

    /// "Tue, Sep 8".
    static func day(_ date: LocalDate) -> String {
        "\(shortWeekday(date.weekday)), \(shortDay(date))"
    }

    /// "Sep 8".
    static func shortDay(_ date: LocalDate) -> String {
        "\(Calendar.school.shortMonthSymbols[date.month - 1]) \(date.day)"
    }

    /// "Tuesday", for a `Calendar` weekday 1...7.
    static func weekday(_ weekday: Int) -> String {
        Calendar.school.weekdaySymbols[weekday - 1]
    }

    /// "Tue", for a `Calendar` weekday 1...7.
    static func shortWeekday(_ weekday: Int) -> String {
        Calendar.school.shortWeekdaySymbols[weekday - 1]
    }

    /// "10 AM", "12 PM".
    static func hour(_ hour: Int) -> String {
        "\(twelveHour(hour)) \(meridiem(hour))"
    }

    /// "10a", "12p": chart axis labels.
    static func compactHour(_ hour: Int) -> String {
        "\(twelveHour(hour))\(hour % 24 < 12 ? "a" : "p")"
    }

    /// The hour starting at `hour`, for "between …": "10 and 11 AM", "11 AM and 12 PM".
    static func hourSpan(_ hour: Int) -> String {
        let end = hour + 1
        guard meridiem(hour) == meridiem(end) else {
            return "\(Self.hour(hour)) and \(Self.hour(end))"
        }
        return "\(twelveHour(hour)) and \(twelveHour(end)) \(meridiem(end))"
    }

    /// "10:42 AM".
    private static func time(_ date: Date) -> String {
        let parts = Calendar.school.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return "\(twelveHour(hour)):\(minute < 10 ? "0" : "")\(minute) \(meridiem(hour))"
    }

    /// "Tue, Sep 8 at 10:42 AM".
    static func moment(_ date: Date) -> String {
        "\(day(LocalDate(date))) at \(time(date))"
    }

    private static func twelveHour(_ hour: Int) -> Int {
        let value = hour % 12
        return value == 0 ? 12 : value
    }

    private static func meridiem(_ hour: Int) -> String {
        hour % 24 < 12 ? "AM" : "PM"
    }
}
