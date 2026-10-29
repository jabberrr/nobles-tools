import SwiftUI
import WidgetKit

/// The top line of every Home Screen widget: an icon chip and a title in the theme's accent
/// color, with an optional detail such as "Today" on the right.
struct WidgetHeader: View {
    let symbol: String
    let title: String
    /// Shown instead of `title` when it doesn't fit.
    var shortTitle: String? = nil
    var detail: String? = nil
    let colors: ThemeColors

    var body: some View {
        HStack(spacing: 6) {
            IconChip(symbol: symbol, colors: colors)
            ViewThatFits(in: .horizontal) {
                Text(title)
                if let shortTitle {
                    Text(shortTitle)
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(colors.accent)
            Spacer(minLength: 4)
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(colors.secondary)
                    .layoutPriority(1)
            }
        }
        .lineLimit(1)
    }
}

/// A filled symbol on an accent-colored disc, marking what a widget or row is about.
struct IconChip: View {
    let symbol: String
    var size: CGFloat = 20
    let colors: ThemeColors

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(.fill)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(colors.onAccent)
            .frame(width: size, height: size)
            .background(colors.accent, in: Circle())
            .widgetAccentable()
    }
}

/// A small uppercase label after an icon, heading a group such as a menu station.
struct Eyebrow: View {
    let symbol: String
    let text: String
    let colors: ThemeColors

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: symbol)
                .symbolVariant(.fill)
            Text(text.uppercased())
                .tracking(0.4)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(colors.accent)
    }
}

/// A rounded tile the size of a row's leading badge, holding a symbol: the sport of a game with
/// no result yet, beside the outcome badges of games with one.
struct SymbolTile: View {
    let symbol: String
    let size: CGFloat
    let colors: ThemeColors

    var body: some View {
        Image(systemName: symbol)
            .symbolVariant(.fill)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(colors.accent)
            .frame(width: size, height: size)
            .background(colors.track, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// A compact empty or error state sized for widgets, standing in for `ContentUnavailableView`,
/// which widgets can't use.
struct WidgetMessage: View {
    let symbol: String
    let title: String
    var detail: String? = nil
    let colors: ThemeColors

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colors.accent)
                .frame(width: 32, height: 32)
                .background(colors.track, in: Circle())
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colors.primary)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(colors.secondary)
                }
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
