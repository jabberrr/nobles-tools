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
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            CountdownLockScreenView(snapshot: snapshot, family: family, style: style, colors: colors, fontDesign: fontDesign)
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    // MARK: State

    private var style: CountdownStyle { design.countdownConfiguration?.style ?? .ring }

    private var fontDesign: Font.Design { design.theme.font.fontDesign }

    // MARK: Building blocks

    private func figure(_ countdown: Countdown, size: CGFloat) -> some View {
        Text(countdown.figure)
            .font(.system(size: countdown.isCounting ? size : size * 0.6, weight: .bold, design: fontDesign))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }

    /// "school days left" under a count; nothing once there's nothing to count.
    @ViewBuilder private func unit(_ countdown: Countdown, font: Font) -> some View {
        if countdown.isCounting {
            Text(countdown.unitText)
                .font(font)
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func ring(_ countdown: Countdown, lineWidth: CGFloat, figureSize: CGFloat) -> some View {
        ZStack {
            ProgressRing(progress: countdown.progress, lineWidth: lineWidth, colors: colors)
            VStack(spacing: 0) {
                figure(countdown, size: figureSize)
                unit(countdown, font: .caption2.weight(.medium))
            }
            .padding(lineWidth + 6)
        }
    }

    private func termName(_ term: Term) -> some View {
        ViewThatFits(in: .horizontal) {
            Text(term.name)
            Text(term.compactName)
        }
        .lineLimit(1)
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
                VStack(spacing: 8) {
                    ring(countdown, lineWidth: 10, figureSize: 34)
                    termName(countdown.term)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colors.accent)
                }
            case .number, .bar:
                VStack(alignment: .leading, spacing: 2) {
                    WidgetHeader(
                        symbol: countdown.term.kind.symbolName,
                        title: countdown.term.name,
                        shortTitle: countdown.term.compactName,
                        colors: colors
                    )
                    Spacer(minLength: 0)
                    figure(countdown, size: style == .number ? 56 : 46)
                    Text(countdown.caption)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(colors.secondary)
                        .lineLimit(2)
                    if style == .bar {
                        ProgressBar(progress: countdown.progress, colors: colors)
                            .frame(height: 7)
                            .padding(.top, 6)
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
                            unit(countdown, font: .footnote.weight(.medium))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 118)

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        WidgetHeader(
                            symbol: countdown.term.kind.symbolName,
                            title: countdown.term.name,
                            shortTitle: countdown.term.compactName,
                            colors: colors
                        )
                        Text(countdown.progressText)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: countdown.term.kind.symbolName)
                    .symbolVariant(.fill)
                    .font(.caption2)
                    .foregroundStyle(colors.accent)
                    .frame(width: 16)
                termName(countdown.term)
                    .font(.caption.weight(.medium))
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
            VStack(alignment: .leading, spacing: 16) {
                WidgetHeader(
                    symbol: "calendar",
                    title: "Countdown",
                    detail: SchoolFormat.weekdayDate(snapshot.date),
                    colors: colors
                )
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                IconChip(symbol: countdown.term.kind.symbolName, size: 28, colors: colors)
                VStack(alignment: .leading, spacing: 1) {
                    termName(countdown.term)
                        .font(isPrimary ? Font.headline : Font.subheadline.weight(.semibold))
                    Text(countdown.progressText)
                        .font(.caption)
                        .foregroundStyle(colors.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    figure(countdown, size: isPrimary ? 32 : 24)
                    unit(countdown, font: .caption2)
                }
                .layoutPriority(1)
            }
            ProgressBar(progress: countdown.progress, colors: colors)
                .frame(height: isPrimary ? 7 : 5)
        }
    }

    private func breakCard(_ schoolBreak: SchoolBreak) -> some View {
        HStack(spacing: 10) {
            IconChip(symbol: BreakSymbol.name(for: schoolBreak), size: 28, colors: colors)
            VStack(alignment: .leading, spacing: 1) {
                Text(schoolBreak.name)
                    .font(.subheadline.weight(.semibold))
                Text(snapshot.timingText(of: schoolBreak))
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
