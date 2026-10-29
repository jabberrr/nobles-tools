import SwiftUI
import WidgetKit
import NoblesKit

/// A countdown on the Lock Screen.
struct CountdownLockScreenView: View {
    let snapshot: CountdownSnapshot
    let family: WidgetFamily
    let style: CountdownStyle
    /// The Lock Screen's colors (see `ThemeColors`), for the progress bar.
    let colors: ThemeColors
    let fontDesign: Font.Design

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    private var symbol: String { (snapshot.primary?.term.kind ?? snapshot.target).symbolName }

    private var noDatesText: String { "No \(snapshot.target.displayName.lowercased()) dates" }

    // MARK: Inline

    /// "131 school days left", "3 weekdays left in Q1".
    private var inline: some View {
        Label(snapshot.primary?.sentence ?? noDatesText, systemImage: symbol)
            .symbolVariant(.fill)
    }

    // MARK: Circular

    /// A ring around the count for the ring and bar styles; just the count for the number style.
    @ViewBuilder private var circular: some View {
        if let countdown = snapshot.primary, countdown.isCounting {
            if style == .number {
                VStack(spacing: -2) {
                    Text("\(countdown.remaining)")
                        .font(.system(size: 24, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                    Text(SchoolFormat.unit(countdown.counting, count: countdown.remaining, compact: true))
                        .font(.caption2)
                        .minimumScaleFactor(0.7)
                }
                .lineLimit(1)
                .padding(6)
                .widgetAccentable()
            } else {
                Gauge(value: countdown.progress) {
                    Text(countdown.term.compactName)
                } currentValueLabel: {
                    Text("\(countdown.remaining)")
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetAccentable()
            }
        } else {
            Image(systemName: finishedSymbol)
                .font(.title3.weight(.semibold))
                .widgetAccentable()
        }
    }

    /// Shown in the circle when there's no count: the last day, all done, or no dates.
    private var finishedSymbol: String {
        switch snapshot.primary?.phase {
        case .lastDay: "flag.checkered"
        case .finished: "checkmark"
        default: "calendar"
        }
    }

    // MARK: Rectangular

    /// The term, the count large over "school days left", and a progress bar.
    @ViewBuilder private var rectangular: some View {
        if let countdown = snapshot.primary {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    ViewThatFits(in: .horizontal) {
                        Text(countdown.term.name)
                        Text(countdown.term.compactName)
                    }
                } icon: {
                    Image(systemName: symbol)
                        .symbolVariant(.fill)
                }
                .font(.footnote.weight(.semibold))
                .widgetAccentable()
                if countdown.isCounting {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(countdown.remaining)")
                            .font(.system(size: 26, weight: .bold, design: fontDesign))
                            .monospacedDigit()
                        Text(countdown.caption)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(countdown.sentence)
                        .font(.headline)
                }
                ProgressBar(progress: countdown.progress, colors: colors)
                    .frame(height: 5)
                    .padding(.top, 2)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Label(noDatesText, systemImage: "calendar")
                .font(.headline)
        }
    }
}
