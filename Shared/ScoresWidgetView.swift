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
                    WidgetMessage(symbol: "line.3.horizontal.decrease", title: "No recent games", detail: content.filterSummary, colors: colors)
                } else {
                    WidgetMessage(symbol: "wifi.slash", title: "Scores unavailable", detail: "Will try again soon", colors: colors)
                }
            }
        }
    }

    private var results: [Game] { content.results }
    private var upcoming: [Game] { content.upcoming }

    // MARK: Small

    /// The result large (or when the next game starts), then the team on its own line, so it
    /// keeps its gender and level, and the opponent.
    private func small(_ game: Game) -> some View {
        let isUpcoming = game.score == nil && game.start > content.now
        return VStack(alignment: .leading, spacing: 2) {
            WidgetHeader(
                symbol: SportSymbol.name(for: game.sport),
                title: game.score != nil ? "Final" : isUpcoming ? "Next Game" : "Latest",
                shortTitle: isUpcoming ? "Next" : nil,
                detail: isUpcoming
                    ? SchoolFormat.relativeDay(LocalDate(game.start), from: content.today)
                    : game.dateText(today: content.today),
                shortDetail: isUpcoming
                    ? SchoolFormat.shortRelativeDay(LocalDate(game.start), from: content.today)
                    : SchoolFormat.shortDate(LocalDate(game.start)),
                colors: colors
            )
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
            } else {
                Text(isUpcoming ? game.startText : game.statusText(now: content.now))
                    .font(.system(size: 26, weight: .bold, design: fontDesign))
                    .foregroundStyle(isUpcoming ? colors.primary : colors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            TeamName(game: game)
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
            if !game.matchupVariants.isEmpty {
                FirstFitting(variants: game.matchupVariants, axes: .vertical) { matchup in
                    Text(matchup)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.footnote)
                .foregroundStyle(colors.secondary)
                .layoutPriority(1)
            }
            if let staleness = content.staleness {
                Text(staleness)
                    .font(.caption2)
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

    /// "Results" over the large list, "Scores" over the medium one (which ends with the next
    /// game), or "Upcoming" when there are no results.
    private var header: some View {
        WidgetHeader(
            symbol: "sportscourt",
            title: results.isEmpty ? "Upcoming" : family == .systemLarge ? "Results" : "Scores",
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
