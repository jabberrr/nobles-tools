import SwiftUI
import WidgetKit
import NoblesKit

/// Spending on the Lock Screen: one figure, so it's never crowded. The figure is the design's
/// highlight, and a meter, when there is one, measures the same thing: the circular size rings it,
/// the rectangular size puts a bar under it, and the inline size reads "Spending · $58.25".
struct StoreLockScreenView: View {
    let content: StoreContent
    let family: WidgetFamily
    /// The Lock Screen's colors (see `ThemeColors`), for the meters.
    let colors: ThemeColors
    let fontDesign: Font.Design

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        default: rectangular
        }
    }

    // MARK: Inline

    /// "Spending · $58.25 of $300", giving up words to fit; it never truncates.
    private var inline: some View {
        FirstFitting(variants: inlineVariants) { Label($0, systemImage: "creditcard") }
    }

    private var inlineVariants: [String] {
        switch content.state {
        case .connect:
            return ["Spending · Connect in app", "Connect in app", "Connect"]
        case .unavailable:
            return ["Spending unavailable", "Unavailable"]
        case .spending(let spending):
            let amount = spending.figure.amount
            if spending.leadsWithLatest {
                return ["Latest charge · \(amount)", "Latest · \(amount)", amount]
            } else if let context = spending.lockContext {
                return ["Spending · \(amount) \(context)", "Spending · \(amount)", amount]
            } else {
                return ["Spending · \(amount)", amount]
            }
        }
    }

    // MARK: Circular

    /// The figure inside a ring that measures the same thing, when there's a limit; else the
    /// credit-card icon over the figure.
    @ViewBuilder private var circular: some View {
        switch content.state {
        case .spending(let spending):
            if let meter = spending.figureMeter {
                // A drawn ring rather than a Gauge, which renders out of proportion in ImageRenderer.
                ZStack {
                    ProgressRing(progress: meter.progress, lineWidth: 7, colors: colors)
                    Text(spending.figure.compactAmount)
                        .font(.system(size: 17, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .widgetAccentable()
                }
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "creditcard")
                        .font(.caption.weight(.semibold))
                        .widgetAccentable()
                    Text(spending.figure.compactAmount)
                        .font(.system(size: 20, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(6)
            }
        case .connect:
            Image(systemName: "creditcard")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
        case .unavailable:
            Image(systemName: "wifi.slash")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
        }
    }

    // MARK: Rectangular

    /// Short lines that fit the smallest Lock Screen: the title, the figure with what it is
    /// ("$58.25 of $300", "$241.75 left"), then — unless the figures are stale ("Sign in to
    /// refresh", "Updated 4h ago") — a bar measuring the same thing, or the latest item on up to
    /// two lines.
    @ViewBuilder private var rectangular: some View {
        switch content.state {
        case .spending(let spending):
            VStack(alignment: .leading, spacing: 1) {
                header
                figureLine(spending)
                if let note = content.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let meter = spending.figureMeter {
                    ProgressBar(progress: meter.progress, colors: colors)
                        .frame(height: 5)
                        .padding(.top, 3)
                } else if let detail = spending.lockDetail {
                    // Two lines where the widget has room, so a long item name shows in full or
                    // nearly; whatever still doesn't fit is cut at the end of the last line.
                    FirstFitting(variants: [2, 1], axes: .vertical) { lines in
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(lines)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .connect:
            rectangularMessage("Connect in app")
        case .unavailable:
            rectangularMessage("Unavailable")
        }
    }

    /// The figure with its context beside it; without cents when that's what it takes to keep the
    /// context; else the figure alone, shrunk rather than ever cut.
    private func figureLine(_ spending: StoreContent.Spending) -> some View {
        let figure = spending.figure
        let variants: [(amount: String, context: String?)] = if let context = spending.lockContext {
            [(figure.amount, context), (figure.compactAmount, context), (figure.amount, nil)]
        } else {
            [(figure.amount, nil)]
        }
        return FirstFitting(variants: variants, axes: .horizontal) { variant in
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(variant.amount)
                    .font(.system(size: 22, weight: .bold, design: fontDesign))
                    .monospacedDigit()
                    .minimumScaleFactor(variant.context == nil ? 0.6 : 1)
                if let context = variant.context {
                    Text(context)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
    }

    private func rectangularMessage(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Spending" after the credit-card icon.
    private var header: some View {
        Label("Spending", systemImage: "creditcard")
            .font(.footnote.weight(.semibold))
            .widgetAccentable()
    }
}
