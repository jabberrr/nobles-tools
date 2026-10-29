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

    /// "W 3–0 vs Concord Academy", shortening the opponent's name (down to initials, "vs BB&N"),
    /// then naming the sport instead, then cutting the name at a word, to fit.
    private var inline: some View {
        FirstFitting(variants: inlineTexts) { text in
            Label(text, systemImage: symbol)
        }
    }

    private var inlineTexts: [String] {
        guard content.isAvailable else { return ["Scores unavailable", "Unavailable"] }
        guard let game = content.featured else { return ["No recent games", "No games"] }
        let lead = leadText(game)
        let cuts = game.matchupVariants.last?.cutsAtWords(limit: 2) ?? []
        return game.matchupVariants.map { "\(lead) \($0)" }
            + ["\(lead) · \(game.shortSport)"]
            + cuts.map { "\(lead) \($0)" }
            + [lead]
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
                    Text(SchoolFormat.shortRelativeDay(LocalDate(game.start), from: content.today))
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

    // MARK: Rectangular

    /// The team; the result (or the day of the next game) large, with its date (or time); then
    /// the opponent, on a second line if need be.
    @ViewBuilder private var rectangular: some View {
        if !content.isAvailable {
            rectangularMessage("Unavailable", detail: "Will try again soon")
        } else if let game = content.featured {
            FirstFitting(variants: game.matchupVariants.isEmpty ? [""] : game.matchupVariants, axes: .vertical) { matchup in
                rectangularGame(game, matchup: matchup)
            }
        } else {
            rectangularMessage("No recent games", detail: content.filterSummary)
        }
    }

    private func rectangularGame(_ game: Game, matchup: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            rectangularHeader {
                TeamName(game: game)
            }
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
            if !matchup.isEmpty {
                Text(matchup)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 1) {
            rectangularHeader {
                Text("Scores")
            }
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The top line, after the sport's icon.
    private func rectangularHeader<Title: View>(@ViewBuilder title: () -> Title) -> some View {
        Label {
            title()
        } icon: {
            Image(systemName: symbol)
        }
        .font(.footnote.weight(.semibold))
        .widgetAccentable()
    }
}
