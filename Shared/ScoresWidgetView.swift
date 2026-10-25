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
    /// The games to show, or `nil` when nothing could be loaded (not even a cached copy).
    let scoreboard: Scoreboard?
    /// The moment on screen (the timeline entry's date).
    let now: Date

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        content
            .fontDesign(design.theme.font.fontDesign)
            .foregroundStyle(colors.primary)
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    // MARK: State

    private var configuration: ScoresConfiguration { design.scoresConfiguration ?? ScoresConfiguration() }

    private var colors: ThemeColors {
        ThemeColors(theme: design.theme, colorScheme: colorScheme, family: family, showsBackground: showsBackground)
    }

    private var today: LocalDate { LocalDate(now) }

    /// Games in progress, then results, newest first.
    private var results: [Game] {
        guard let scoreboard else { return [] }
        return scoreboard.live + scoreboard.recent.sorted { $0.start > $1.start }
    }

    /// Upcoming games, soonest first; empty when the design hides them.
    private var upcoming: [Game] {
        guard let scoreboard, configuration.showsUpcoming else { return [] }
        return scoreboard.upcoming.sorted { $0.start < $1.start }
    }

    /// "Updated 3h ago" when the scoreboard is an older cached copy.
    private var staleness: String? {
        guard let scoreboard, now.timeIntervalSince(scoreboard.fetchedAt) > 60 * 60,
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
                Text(staleness ?? dateText(game))
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
                Text(whenText(game))
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
            Text(statusText(game))
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
            Text(whenText(game))
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
                    FittingList(items: upcoming, capacity: 5, spacing: 6, overflowColor: colors.secondary) { upcomingRow($0) }
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
                if !game.matchupText.isEmpty {
                    Text(game.matchupText)
                        .font(.caption2)
                        .foregroundStyle(colors.secondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(game.score.flatMap(\.scoreline) ?? game.score?.outcome.word ?? statusText(game))
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                Text(dateText(game))
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
            }
            .lineLimit(1)
            .layoutPriority(1)
        }
    }

    private func upcomingRow(_ game: Game) -> some View {
        HStack(spacing: 8) {
            Image(systemName: SportSymbol.name(for: game.sport))
                .font(.caption)
                .foregroundStyle(colors.accent)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(game.teamText)
                    .font(.footnote.weight(.semibold))
                if !game.matchupText.isEmpty {
                    Text(game.matchupText)
                        .font(.caption2)
                        .foregroundStyle(colors.secondary)
                }
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
                Text(game.score == nil && game.start > now ? whenText(game) : dateText(game))
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
        let status = game.score == nil && game.start <= now ? statusText(game) : nil
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

    // MARK: Text

    /// "Oct 19", or "Today" / "Yesterday" for recent games.
    private func dateText(_ game: Game) -> String {
        let day = LocalDate(game.start)
        return abs(today.days(until: day)) <= 1 ? SchoolFormat.relativeDay(day, from: today) : SchoolFormat.shortDate(day)
    }

    /// "Wed 4:00 PM", "Today 4:00 PM", or just the day when no time is known.
    private func whenText(_ game: Game) -> String {
        let day = LocalDate(game.start)
        let dayText = today.days(until: day) <= 1 ? SchoolFormat.relativeDay(day, from: today) : SchoolFormat.weekday(day)
        return game.hasStartTime ? "\(dayText) \(SchoolFormat.time(game.start))" : dayText
    }

    /// Stands in for a score when there isn't one.
    private func statusText(_ game: Game) -> String {
        switch game.status {
        case .live(let detail): ["Live", detail].compactMap { $0 }.joined(separator: " · ")
        case .postponed: "Postponed"
        case .cancelled: "Cancelled"
        case .final: "Final"
        case .scheduled: game.start <= now ? "Awaiting result" : whenText(game)
        }
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

extension ScoresConfiguration {
    /// What the design is filtered to, e.g. "Varsity · Boys Soccer, Girls Soccer".
    var summaryText: String {
        let level = varsityOnly ? "Varsity" : "All levels"
        let teams = sports.isEmpty ? "All sports" : sports.joined(separator: ", ")
        return "\(level) · \(teams)"
    }
}

extension GameScore.Outcome {
    var word: String {
        switch self {
        case .win: "Win"
        case .loss: "Loss"
        case .tie: "Tie"
        }
    }
}

extension Game {
    /// "Boys Soccer · JV": the level is left out for varsity teams.
    var teamText: String {
        guard let level, !level.isEmpty, level.caseInsensitiveCompare("Varsity") != .orderedSame else { return sport }
        return "\(sport) · \(level)"
    }

    /// "vs Thayer Academy", "at Tabor Academy", or empty for a meet with no single opponent.
    var matchupText: String {
        guard !opponent.isEmpty else { return "" }
        return "\(isHome == false ? "at" : "vs") \(opponent)"
    }
}

/// SF Symbols for Nobles sports, matched loosely against names like "Girls Field Hockey".
enum SportSymbol {
    private static let table: [(keyword: String, symbol: String)] = [
        ("field hockey", "figure.hockey"),
        ("hockey", "hockey.puck"),
        ("soccer", "soccerball"),
        ("football", "football"),
        ("basketball", "basketball"),
        ("volleyball", "volleyball"),
        ("baseball", "baseball"),
        ("softball", "baseball"),
        ("lacrosse", "figure.lacrosse"),
        ("tennis", "tennis.racket"),
        ("pickleball", "tennis.racket"),
        ("squash", "figure.squash"),
        ("cross country", "figure.run"),
        ("track", "figure.run"),
        ("swim", "figure.pool.swim"),
        ("diving", "figure.pool.swim"),
        ("ski", "figure.skiing.downhill"),
        ("wrestling", "figure.wrestling"),
        ("golf", "figure.golf"),
        ("crew", "figure.rower"),
        ("rowing", "figure.rower"),
        ("sailing", "sailboat"),
        ("fencing", "figure.fencing"),
    ]

    static func name(for sport: String) -> String {
        let key = sport.lowercased()
        return table.first { key.contains($0.keyword) }?.symbol ?? "sportscourt"
    }
}
