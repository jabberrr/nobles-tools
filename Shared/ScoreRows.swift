import SwiftUI
import NoblesKit

/// A game's team on one line, shortened to fit: "Girls Field Hockey · JV", then "Girls Field
/// Hockey", then "Field Hockey".
struct TeamName: View {
    let game: Game

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(game.teamText)
            Text(game.sport)
            Text(game.shortSport)
        }
        .lineLimit(1)
    }
}

/// "vs Buckingham Browne & Nichols School" on one line, or "vs Buckingham Browne & Nichols" when
/// that doesn't fit. With `showsVenue`, " · Nobles-Burr Field" follows when the whole line fits.
struct MatchupName: View {
    let game: Game
    var showsVenue = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if showsVenue, let venue = game.venueText {
                Text([game.matchupText, venue].filter { !$0.isEmpty }.joined(separator: " · "))
            }
            Text(game.matchupText)
            Text(game.shortMatchupText)
        }
        .lineLimit(1)
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

/// A rounded "W", "L" or "T" tile; wins are filled with the accent color.
struct OutcomeBadge: View {
    let outcome: GameScore.Outcome
    let size: CGFloat
    let colors: ThemeColors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        Text(outcome.rawValue)
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
            .foregroundStyle(outcome == .win ? colors.onAccent : colors.primary)
            .frame(width: size, height: size)
            .background(outcome == .win ? colors.accent : colors.track, in: shape)
            .accessibilityLabel(outcome.word)
    }
}
