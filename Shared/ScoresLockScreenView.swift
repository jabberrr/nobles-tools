import SwiftUI
import WidgetKit
import NoblesKit

/// Scores on the Lock Screen: the latest result, or else the next game.
struct ScoresLockScreenView: View {
    let content: ScoresContent
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    private var symbol: String {
        content.featured.map { SportSymbol.name(for: $0.sport) } ?? "sportscourt"
    }

    /// The result ("W 3–0"), or what stands in for one: when the game starts, or its status.
    private func leadText(_ game: Game) -> String {
        game.resultText ?? game.statusText(now: content.now)
    }

    // MARK: Inline

    /// "W 3–0 vs Concord Academy", shortening the opponent, then leaving it out, to fit.
    private var inline: some View {
        let texts = inlineTexts
        return ViewThatFits {
            Label(texts.long, systemImage: symbol)
            Label(texts.medium, systemImage: symbol)
            Label(texts.short, systemImage: symbol)
        }
    }

    private var inlineTexts: (long: String, medium: String, short: String) {
        guard content.isAvailable else { return ("Scores unavailable", "Unavailable", "Unavailable") }
        guard let game = content.featured else { return ("No recent games", "No games", "No games") }
        let lead = leadText(game)
        func withMatchup(_ matchup: String) -> String { matchup.isEmpty ? lead : "\(lead) \(matchup)" }
        return (withMatchup(game.matchupText), withMatchup(game.shortMatchupText), lead)
    }

    // MARK: Circular

    /// The sport's icon over the outcome and score, or over the day and time of the next game.
    @ViewBuilder private var circular: some View {
        if let game = content.featured {
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .widgetAccentable()
                if let score = game.score {
                    Text(score.outcome.rawValue)
                        .font(.title2.weight(.bold))
                    Text(score.scoreline ?? game.dateText(today: content.today))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text(dayWord(game))
                        .font(.headline)
                    if game.hasStartTime {
                        Text(SchoolFormat.time(game.start))
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(6)
        } else {
            Image(systemName: content.isAvailable ? "sportscourt" : "wifi.slash")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
        }
    }

    /// "Today", or the weekday: "Wed".
    private func dayWord(_ game: Game) -> String {
        let day = LocalDate(game.start)
        return day == content.today ? "Today" : SchoolFormat.weekday(day)
    }

    // MARK: Rectangular

    /// The team; the result (or the day of the next game) large, with its date (or time); then
    /// the opponent.
    @ViewBuilder private var rectangular: some View {
        if !content.isAvailable {
            rectangularMessage("Scores unavailable", detail: "Will try again soon")
        } else if let game = content.featured {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    TeamName(game: game)
                } icon: {
                    Image(systemName: symbol)
                }
                .font(.footnote.weight(.semibold))
                .widgetAccentable()
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(headline(game))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(detail(game))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                }
                .lineLimit(1)
                if !game.matchupText.isEmpty {
                    MatchupName(game: game)
                        .font(.footnote)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            rectangularMessage("No recent games", detail: content.filterSummary)
        }
    }

    /// "W 3–0" for a result, the day for a game to come, or a status such as "Postponed".
    private func headline(_ game: Game) -> String {
        if let result = game.resultText { return result }
        guard game.start > content.now, game.status == .scheduled else { return game.statusText(now: content.now) }
        return SchoolFormat.relativeDay(LocalDate(game.start), from: content.today)
    }

    /// The date of a result, or the start time of a game to come.
    private func detail(_ game: Game) -> String {
        guard game.score == nil, game.start > content.now else { return game.dateText(today: content.today) }
        return game.hasStartTime ? SchoolFormat.time(game.start) : ""
    }

    private func rectangularMessage(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: "sportscourt")
                .font(.headline)
                .widgetAccentable()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
