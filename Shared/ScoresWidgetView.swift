import SwiftUI
import WidgetKit
import NoblesKit

/// A scores design rendered at one widget size. The widget and the app's previews both use it.
///
/// Nobles Athletics posts final results only, about a week behind, so nothing here says "live"
/// unless a game's status really is `.live`.
struct ScoresWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The games to show, or `nil` when nothing could be loaded (not even a cached copy).
    let scoreboard: Scoreboard?
    /// The moment on screen (the timeline entry's date).
    let now: Date

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    // MARK: State

    private var configuration: ScoresConfiguration { design.scoresConfiguration ?? ScoresConfiguration() }

    private var today: LocalDate { LocalDate(now) }

    /// Games in progress, then results (and games awaiting one), newest first.
    private var results: [Game] {
        guard let scoreboard else { return [] }
        return scoreboard.live + scoreboard.recent
    }

    /// Upcoming games, soonest first; empty when the design hides them.
    private var upcoming: [Game] {
        guard let scoreboard, configuration.showsUpcoming else { return [] }
        return scoreboard.upcoming
    }

    /// "Updated 3h ago" when the scoreboard is an older cached copy. The threshold sits above the
    /// widget's 2-hour refresh, so data that is merely between refreshes isn't flagged.
    private var staleness: String? {
        guard let scoreboard, now.timeIntervalSince(scoreboard.fetchedAt) > 3 * 60 * 60,
              let age = SchoolFormat.age(of: scoreboard.fetchedAt, now: now)
        else { return nil }
        return "Updated \(age)"
    }

    // MARK: Small

    @ViewBuilder private var small: some View {
        if scoreboard == nil {
            unavailable
        } else if let game = results.first {
            VStack(alignment: .leading, spacing: 3) {
                teamLine(game)
                Spacer(minLength: 0)
                bigResult(game)
                Text(game.matchupText.isEmpty ? game.teamText : game.matchupText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(staleness ?? game.dateText(today: today))
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let game = upcoming.first {
            VStack(alignment: .leading, spacing: 3) {
                Text("Next Game")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.accent)
                Spacer(minLength: 0)
                teamLine(game)
                Text(game.matchupText.isEmpty ? game.teamText : game.matchupText)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(game.whenText(today: today))
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            empty
        }
    }

    /// The outcome badge and score, or a status such as "Awaiting result".
    @ViewBuilder private func bigResult(_ game: Game) -> some View {
        if let score = game.score {
            HStack(alignment: .center, spacing: 8) {
                OutcomeBadge(outcome: score.outcome, size: 30, colors: colors)
                Text(score.scoreline ?? score.outcome.word)
                    .font(.system(size: 28, weight: .bold, design: design.theme.font.fontDesign))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        } else {
            Text(game.statusText(now: now))
                .font(.headline)
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Medium

    @ViewBuilder private var medium: some View {
        if scoreboard == nil {
            unavailable
        } else if results.isEmpty && upcoming.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header(results.isEmpty ? "Upcoming" : "Recent Results")
                if results.isEmpty {
                    FittingList(items: upcoming, capacity: 3, spacing: 5) { upcomingRow($0) }
                } else {
                    FittingList(items: results, capacity: 3, spacing: 5) { resultRow($0) }
                    Spacer(minLength: 0)
                    if let next = upcoming.first {
                        nextLine(next)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// "Next: Boys Soccer vs Thayer Academy · Wed 4:00 PM"
    private func nextLine(_ game: Game) -> some View {
        HStack(spacing: 4) {
            Text("Next")
                .fontWeight(.semibold)
                .foregroundStyle(colors.accent)
            Text([game.teamText, game.matchupText].filter { !$0.isEmpty }.joined(separator: " "))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(game.whenText(today: today))
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .font(.caption)
    }

    // MARK: Large

    @ViewBuilder private var large: some View {
        if scoreboard == nil {
            unavailable
        } else if results.isEmpty && upcoming.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header("Recent Results")
                if results.isEmpty {
                    Text("No results posted yet")
                        .font(.footnote)
                        .foregroundStyle(colors.secondary)
                } else {
                    FittingList(items: results, capacity: 7, spacing: 6, overflowColor: colors.secondary) { resultRow($0) }
                }
                if !upcoming.isEmpty {
                    sectionTitle("Upcoming")
                        .padding(.top, 4)
                    FittingList(items: upcoming, capacity: 5, spacing: 6, overflowColor: colors.secondary) { upcomingRow($0, showsVenue: true) }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Rows

    private func header(_ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sportscourt")
            Text(title)
            Spacer(minLength: 4)
            if let staleness {
                Text(staleness)
                    .foregroundStyle(colors.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(colors.accent)
        .lineLimit(1)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(colors.accent)
    }

    private func teamLine(_ game: Game) -> some View {
        Label(game.teamText, systemImage: SportSymbol.name(for: game.sport))
            .font(.caption.weight(.semibold))
            .foregroundStyle(colors.accent)
            .lineLimit(1)
    }

    private func resultRow(_ game: Game) -> some View {
        HStack(spacing: 8) {
            if let score = game.score {
                OutcomeBadge(outcome: score.outcome, size: 22, colors: colors)
            } else {
                Image(systemName: SportSymbol.name(for: game.sport))
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(game.teamText)
                    .font(.footnote.weight(.semibold))
                matchupLine(game)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(game.score.flatMap(\.scoreline) ?? game.score?.outcome.word ?? game.statusText(now: now))
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                Text(game.dateText(today: today))
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }

    private func upcomingRow(_ game: Game, showsVenue: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: SportSymbol.name(for: game.sport))
                .font(.caption)
                .foregroundStyle(colors.accent)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(game.teamText)
                    .font(.footnote.weight(.semibold))
                matchupLine(game, showsVenue: showsVenue)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(SchoolFormat.relativeDay(LocalDate(game.start), from: today))
                    .font(.caption.weight(.semibold))
                if game.hasStartTime {
                    Text(SchoolFormat.time(game.start))
                        .font(.caption2)
                        .foregroundStyle(colors.secondary)
                }
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }

    /// "vs Thayer Academy", followed by " · Nobles-Burr Field" when `showsVenue` and the whole
    /// line fits: a venue cut off mid-name isn't worth the space.
    @ViewBuilder private func matchupLine(_ game: Game, showsVenue: Bool = false) -> some View {
        let matchup = game.matchupText
        if showsVenue, let venue = game.venueText {
            if matchup.isEmpty {
                detailText(venue)
            } else {
                ViewThatFits(in: .horizontal) {
                    detailText("\(matchup) · \(venue)")
                    detailText(matchup)
                }
            }
        } else if !matchup.isEmpty {
            detailText(matchup)
        }
    }

    private func detailText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(colors.secondary)
    }

    // MARK: Lock Screen

    @ViewBuilder private var rectangular: some View {
        if scoreboard == nil {
            Label("Scores unavailable", systemImage: "sportscourt")
                .font(.headline)
        } else if let game = results.first ?? upcoming.first {
            VStack(alignment: .leading, spacing: 1) {
                Label(game.teamText, systemImage: SportSymbol.name(for: game.sport))
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(rectangularSummary(game))
                    .font(.subheadline)
                    .lineLimit(1)
                Text(game.score == nil && game.start > now ? game.whenText(today: today) : game.dateText(today: today))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label("No recent games", systemImage: "sportscourt")
                .font(.headline)
        }
    }

    /// "W 3–0 vs Concord Academy", or "vs Thayer Academy" for a game still to come.
    private func rectangularSummary(_ game: Game) -> String {
        let result = game.score.map { [$0.outcome.rawValue, $0.scoreline].compactMap { $0 }.joined(separator: " ") }
        let status = game.score == nil && game.start <= now ? game.statusText(now: now) : nil
        return [result, status, game.matchupText.isEmpty ? nil : game.matchupText]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    // MARK: Empty and error states

    private var unavailable: some View {
        WidgetMessage(symbol: "sportscourt", title: "Scores unavailable", detail: "Will try again soon", colors: colors)
    }

    private var empty: some View {
        WidgetMessage(symbol: "sportscourt", title: "No recent games", detail: configuration.summaryText, colors: colors)
    }
}

/// A rounded "W", "L" or "T" tile; wins are filled with the accent color.
private struct OutcomeBadge: View {
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
