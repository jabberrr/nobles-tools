import SwiftUI
import WidgetKit
import NoblesKit

/// A game's team on one line, shortened to fit (see `Game.teamVariants`).
struct TeamName: View {
    let game: Game

    var body: some View {
        FirstFitting(variants: game.teamVariants, axes: .horizontal) { Text($0) }
            .lineLimit(1)
    }
}

/// The matchup on one line, shortened to fit (see `Game.matchupVariants`). With `showsVenue`,
/// " · Nobles-Burr Field" follows when the whole line fits.
struct MatchupName: View {
    let game: Game
    var showsVenue = false

    var body: some View {
        FirstFitting(variants: variants, axes: .horizontal) { Text($0) }
            .lineLimit(1)
    }

    private var variants: [String] {
        guard showsVenue, let venue = game.venueText else { return game.matchupVariants }
        return [[game.matchupText, venue].filter { !$0.isEmpty }.joined(separator: " · ")] + game.matchupVariants
    }
}

/// A game on one row: a badge, the team over its opponent, and two right-aligned lines.
struct GameRow<Badge: View, Trailing: View>: View {
    let game: Game
    var showsVenue = false
    let colors: ThemeColors
    @ViewBuilder let badge: Badge
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            badge
            VStack(alignment: .leading, spacing: 1) {
                TeamName(game: game)
                    .font(.footnote.weight(.semibold))
                if !game.matchupText.isEmpty {
                    MatchupName(game: game, showsVenue: showsVenue)
                        .font(.caption2)
                        .foregroundStyle(colors.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                trailing
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }
}

/// A result: outcome badge, team and opponent, score and date.
struct ResultRow: View {
    let game: Game
    let content: ScoresContent
    let colors: ThemeColors

    var body: some View {
        GameRow(game: game, colors: colors) {
            if let score = game.score {
                OutcomeBadge(outcome: score.outcome, size: 26, colors: colors)
            } else {
                SymbolTile(symbol: SportSymbol.name(for: game.sport), size: 26, colors: colors)
            }
        } trailing: {
            Text(game.score.flatMap(\.scoreline) ?? game.score?.outcome.word ?? game.statusText(now: content.now))
                .font(.footnote.weight(.bold))
                .monospacedDigit()
            Text(game.dateText(today: content.today))
                .font(.caption2)
                .foregroundStyle(colors.secondary)
        }
    }
}

/// A game still to come: sport tile, team and opponent, day and start time.
struct UpcomingRow: View {
    let game: Game
    let content: ScoresContent
    var showsVenue = false
    let colors: ThemeColors

    var body: some View {
        GameRow(game: game, showsVenue: showsVenue, colors: colors) {
            SymbolTile(symbol: SportSymbol.name(for: game.sport), size: 26, colors: colors)
        } trailing: {
            Text(SchoolFormat.relativeDay(LocalDate(game.start), from: content.today))
                .font(.footnote.weight(.semibold))
            if game.hasStartTime {
                Text(SchoolFormat.time(game.start))
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
            }
        }
    }
}

/// A rounded "W", "L" or "T" tile. A win is an accent-colored tile with its letter cut out, which
/// keeps its shape in the Home Screen's tinted and clear modes (see `IconChip`).
struct OutcomeBadge: View {
    let outcome: GameScore.Outcome
    let size: CGFloat
    let colors: ThemeColors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        let letter = Text(outcome.rawValue)
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
        Group {
            if outcome == .win {
                shape
                    .fill(colors.accent)
                    .overlay { letter.blendMode(.destinationOut) }
                    .compositingGroup()
                    .widgetAccentable()
            } else {
                letter
                    .foregroundStyle(colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.track, in: shape)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(outcome.word)
    }
}
