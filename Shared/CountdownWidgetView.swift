import SwiftUI
import WidgetKit
import NoblesKit

/// A countdown design rendered at one widget size. The widget and the app's previews both use it.
struct CountdownWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    let snapshot: CountdownSnapshot

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    // MARK: State

    private var style: CountdownStyle { design.countdownConfiguration?.style ?? .ring }

    private var fontDesign: Font.Design { design.theme.font.fontDesign }

    /// "63% complete · ends Fri, Jan 22", "Starts Mon, Sep 8", …
    private func progressDetail(_ countdown: Countdown) -> String {
        switch countdown.phase {
        case .upcoming: "Starts \(SchoolFormat.weekdayDate(countdown.term.span.start))"
        case .inProgress: "\(countdown.percentComplete) complete · ends \(SchoolFormat.weekdayDate(countdown.term.span.end))"
        case .lastDay: "Last day today"
        case .finished: "Ended \(SchoolFormat.weekdayDate(countdown.term.span.end))"
        }
    }

    /// "In 26 days · Nov 25 – 29", or "Through Nov 29" during the break.
    private func breakDetail(_ schoolBreak: SchoolBreak) -> String {
        if schoolBreak.span.contains(snapshot.date) {
            return "Now · through \(SchoolFormat.shortDate(schoolBreak.span.end))"
        }
        let days = snapshot.date.days(until: schoolBreak.span.start)
        let when = days == 1 ? "Tomorrow" : "In \(days) days"
        return "\(when) · \(SchoolFormat.span(schoolBreak.span))"
    }

    // MARK: Building blocks

    private func figure(_ countdown: Countdown, size: CGFloat) -> some View {
        Text(countdown.figure)
            .font(.system(size: countdown.isCounting ? size : size * 0.6, weight: .bold, design: fontDesign))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    private func termLabel(_ countdown: Countdown) -> some View {
        Text(countdown.term.name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(colors.accent)
            .lineLimit(1)
    }

    private func ring(_ countdown: Countdown, lineWidth: CGFloat, figureSize: CGFloat) -> some View {
        ZStack {
            ProgressRing(progress: countdown.progress, lineWidth: lineWidth, colors: colors)
            VStack(spacing: 0) {
                figure(countdown, size: figureSize)
                if countdown.isCounting {
                    Text(SchoolFormat.unit(countdown.counting, count: countdown.remaining))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(colors.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(lineWidth + 6)
        }
    }

    private var noDates: some View {
        WidgetMessage(
            symbol: "calendar",
            title: "No \(snapshot.target.displayName.lowercased()) dates",
            detail: "Add them in Nobles Tools settings",
            colors: colors
        )
    }

    // MARK: Small

    @ViewBuilder private var small: some View {
        if let countdown = snapshot.primary {
            switch style {
            case .ring:
                VStack(spacing: 6) {
                    ring(countdown, lineWidth: 9, figureSize: 34)
                    termLabel(countdown)
                }
            case .number, .bar:
                VStack(alignment: .leading, spacing: 2) {
                    termLabel(countdown)
                    Spacer(minLength: 0)
                    figure(countdown, size: style == .number ? 56 : 46)
                    Text(countdown.caption)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(colors.secondary)
                        .lineLimit(2)
                    if style == .bar {
                        ProgressBar(progress: countdown.progress, colors: colors)
                            .frame(height: 7)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        } else {
            noDates
        }
    }

    // MARK: Medium

    @ViewBuilder private var medium: some View {
        if let countdown = snapshot.primary {
            HStack(spacing: 16) {
                Group {
                    switch style {
                    case .ring:
                        ring(countdown, lineWidth: 10, figureSize: 36)
                    case .number, .bar:
                        VStack(alignment: .leading, spacing: 0) {
                            figure(countdown, size: 54)
                            Text(countdown.isCounting ? SchoolFormat.unit(countdown.counting, count: countdown.remaining) : countdown.term.name)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(colors.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 118)

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countdown.term.name)
                            .font(.headline)
                            .foregroundStyle(colors.accent)
                            .lineLimit(1)
                        Text(progressDetail(countdown))
                            .font(.caption)
                            .foregroundStyle(colors.secondary)
                            .lineLimit(2)
                    }
                    if style == .bar {
                        ProgressBar(progress: countdown.progress, colors: colors)
                            .frame(height: 6)
                    }
                    Spacer(minLength: 0)
                    ForEach(snapshot.others, id: \.term.id) { other in
                        otherRow(other)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            noDates
        }
    }

    private func otherRow(_ countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(countdown.term.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(countdown.isCounting ? "\(countdown.remaining)" : countdown.figure)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            ProgressBar(progress: countdown.progress, colors: colors)
                .frame(height: 4)
        }
    }

    // MARK: Large

    @ViewBuilder private var large: some View {
        if snapshot.countdowns.isEmpty {
            noDates
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Countdown", systemImage: "calendar.badge.clock")
                    Spacer(minLength: 4)
                    Text(SchoolFormat.weekdayDate(snapshot.date))
                        .foregroundStyle(colors.secondary)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(colors.accent)
                .lineLimit(1)

                ForEach(snapshot.countdowns, id: \.term.id) { countdown in
                    largeRow(countdown, isPrimary: countdown.term.kind == snapshot.target)
                }

                Spacer(minLength: 0)

                if let nextBreak = snapshot.nextBreak {
                    breakCard(nextBreak)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func largeRow(_ countdown: Countdown, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(countdown.term.name)
                        .font(isPrimary ? Font.headline : Font.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(progressDetail(countdown))
                        .font(.caption)
                        .foregroundStyle(colors.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    figure(countdown, size: isPrimary ? 34 : 24)
                    if countdown.isCounting {
                        Text(SchoolFormat.unit(countdown.counting, count: countdown.remaining))
                            .font(.caption2)
                            .foregroundStyle(colors.secondary)
                    }
                }
            }
            ProgressBar(progress: countdown.progress, colors: colors)
                .frame(height: isPrimary ? 8 : 5)
        }
    }

    private func breakCard(_ schoolBreak: SchoolBreak) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "beach.umbrella")
                .font(.title3)
                .foregroundStyle(colors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(schoolBreak.name)
                    .font(.subheadline.weight(.semibold))
                Text(breakDetail(schoolBreak))
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(colors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Lock Screen

    @ViewBuilder private var circular: some View {
        if let countdown = snapshot.primary, countdown.isCounting, style != .number {
            Gauge(value: countdown.progress) {
                Text(countdown.term.compactName)
            } currentValueLabel: {
                Text("\(countdown.remaining)")
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                if let countdown = snapshot.primary, countdown.isCounting {
                    VStack(spacing: -2) {
                        Text("\(countdown.remaining)")
                            .font(.system(size: 24, weight: .bold, design: fontDesign))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                        Text(SchoolFormat.unit(countdown.counting, count: countdown.remaining, compact: true))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .widgetAccentable()
                } else {
                    Image(systemName: circularSymbol)
                        .font(.title3.weight(.semibold))
                        .widgetAccentable()
                }
            }
        }
    }

    /// Shown in the circle when there's no count: the last day, all done, or no dates.
    private var circularSymbol: String {
        switch snapshot.primary?.phase {
        case .lastDay: "flag.checkered"
        case .finished: "checkmark"
        default: "calendar"
        }
    }

    @ViewBuilder private var rectangular: some View {
        if let countdown = snapshot.primary {
            VStack(alignment: .leading, spacing: 2) {
                Text(countdown.term.name)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(countdown.isCounting ? "\(countdown.figure) \(countdown.caption)" : countdown.sentence)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Gauge(value: countdown.progress) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No \(snapshot.target.displayName.lowercased()) dates")
                .font(.headline)
        }
    }

    private var inline: some View {
        Label(snapshot.primary?.sentence ?? "No \(snapshot.target.displayName.lowercased()) dates", systemImage: "calendar")
    }
}
