import SwiftUI
import WidgetKit
import NoblesKit

/// A scores design rendered at one widget size. The widget and the app's previews both use it.
struct ScoresWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The games to show, or `nil` when nothing could be loaded (not even a cached copy).
    let scoreboard: Scoreboard?
    /// The moment on screen (the timeline entry's date).
    let now: Date

    var body: some View {
        let configuration = design.scoresConfiguration ?? ScoresConfiguration()
        let content = ScoresContent(scoreboard: scoreboard, configuration: configuration, now: now)
        if family.isAccessory {
            ScoresLockScreenView(content: content, family: family)
        } else {
            ScoresHomeScreenView(content: content, family: family, colors: colors, fontDesign: design.theme.font.fontDesign)
        }
    }
}

/// Scores on the Home Screen: the latest game large on the small size, lists on the others.
private struct ScoresHomeScreenView: View {
    let content: ScoresContent
    let family: WidgetFamily
    let colors: ThemeColors
    let fontDesign: Font.Design

    var body: some View {
        if let featured = content.featured {
            switch family {
            case .systemSmall: small(featured)
            case .systemMedium: medium
            default: large
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(symbol: "sportscourt", title: "Scores", colors: colors)
                if content.isAvailable {
                    WidgetMessage(symbol: "sportscourt", title: "No recent games", detail: content.filterSummary, colors: colors)
                } else {
                    WidgetMessage(symbol: "wifi.slash", title: "Scores unavailable", detail: "Will try again soon", colors: colors)
                }
            }
        }
    }

    private var results: [Game] { content.results }
    private var upcoming: [Game] { content.upcoming }

    // MARK: Small

    /// The game's sport, its result (or when it starts), and the opponent.
    private func small(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetHeader(symbol: SportSymbol.name(for: game.sport), title: game.teamText, shortTitle: game.shortSport, colors: colors)
            Spacer(minLength: 4)
            if let score = game.score {
                HStack(spacing: 8) {
                    OutcomeBadge(outcome: score.outcome, size: 30, colors: colors)
                    Text(score.scoreline ?? score.outcome.word)
                        .font(.system(size: 30, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            } else if game.start > content.now {
                Eyebrow(symbol: "calendar", text: "Next game", colors: colors)
                Text(game.whenText(today: content.today))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(game.statusText(now: content.now))
                    .font(.headline)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
            if !game.matchupText.isEmpty {
                ViewThatFits(in: .vertical) {
                    Text(game.matchupText)
                    Text(game.shortMatchupText)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.top, 2)
                .layoutPriority(1)
            }
            if game.score != nil || game.start <= content.now {
                Text(content.staleness ?? game.dateText(today: content.today))
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium

    /// Recent results, then the next game under a rule; or upcoming games when there are no
    /// results. Spacing is tight so two results and the next game fit.
    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 6)
            if results.isEmpty {
                FittingList(items: upcoming, capacity: 3, spacing: 6) { upcomingRow($0) }
            } else {
                FittingList(items: results, capacity: upcoming.isEmpty ? 3 : 2, spacing: 6) { resultRow($0) }
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if let next = upcoming.first {
                    upcomingRow(next)
                        .padding(.top, 6)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(colors.track)
                                .frame(height: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Large

    /// Recent results, then upcoming games with their venues.
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if !results.isEmpty {
                FittingList(items: results, capacity: 4, spacing: 7, overflowColor: colors.secondary) { resultRow($0) }
                    .layoutPriority(2)
            }
            if !results.isEmpty, !upcoming.isEmpty {
                Eyebrow(symbol: "calendar", text: "Upcoming", colors: colors)
                    .padding(.top, 6)
            }
            if !upcoming.isEmpty {
                FittingList(items: upcoming, capacity: 4, spacing: 7, overflowColor: colors.secondary) {
                    upcomingRow($0, showsVenue: true)
                }
                .layoutPriority(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Building blocks

    private var header: some View {
        WidgetHeader(
            symbol: "sportscourt",
            title: results.isEmpty ? "Upcoming" : "Results",
            detail: content.staleness,
            shortDetail: content.age,
            colors: colors
        )
    }

    private func resultRow(_ game: Game) -> some View {
        ResultRow(game: game, content: content, colors: colors)
    }

    private func upcomingRow(_ game: Game, showsVenue: Bool = false) -> some View {
        UpcomingRow(game: game, content: content, showsVenue: showsVenue, colors: colors)
    }
}
