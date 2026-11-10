import SwiftUI
import WidgetKit
import NoblesKit

/// Spending on the Lock Screen: one figure, so it's never crowded. The circular size shows a
/// spent-against-limit gauge when a limit is set, the inline size "Spending · $136.75", and the
/// rectangular size the figure with its limit or latest item.
struct StoreLockScreenView: View {
    let content: StoreContent
    let family: WidgetFamily
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

    // MARK: Inline

    /// "Spending · $136.75", giving up the label to fit; it never truncates.
    private var inline: some View {
        FirstFitting(variants: inlineVariants) { Label($0, systemImage: "creditcard") }
    }

    private var inlineVariants: [String] {
        switch content.state {
        case .connect: ["Spending · Connect in app", "Connect in app", "Connect"]
        case .unavailable: ["Spending unavailable", "Unavailable"]
        case .spending(let spending): ["Spending · \(spending.figure.amount)", spending.figure.amount]
        }
    }

    // MARK: Circular

    /// A spent-against-limit gauge when a limit is set, else the credit-card icon over the figure.
    @ViewBuilder private var circular: some View {
        switch content.state {
        case .spending(let spending):
            if let progress = spending.progress {
                // A drawn ring (not a Gauge, which renders out of proportion in ImageRenderer) that
                // fills with what's been spent, so its centre shows the spent amount too — not the
                // design's highlight — otherwise ring and number would measure opposites.
                ZStack {
                    ProgressRing(progress: progress, lineWidth: 7, colors: colors)
                    Text(spending.spentCompact)
                        .font(.system(size: 17, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
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

    /// The figure large, with the limit or latest item beside it, over a progress bar when limited.
    @ViewBuilder private var rectangular: some View {
        switch content.state {
        case .spending(let spending):
            VStack(alignment: .leading, spacing: 2) {
                header
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(spending.figure.amount)
                        .font(.system(size: 24, weight: .bold, design: fontDesign))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 4)
                    if let detail = rectangularDetail(spending) {
                        Text(detail)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                    }
                }
                .lineLimit(1)
                if let progress = spending.progress {
                    ProgressBar(progress: progress, colors: colors)
                        .frame(height: 5)
                        .padding(.top, 2)
                    if let caption = spending.limitCaption {
                        Text(caption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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

    /// With a limit, the figure's own label ("Left"/"Spent") so the big number is never mistaken
    /// for a spent-of-limit figure; the spent-against-limit context then sits under the bar. With
    /// no limit, the latest item instead.
    private func rectangularDetail(_ spending: StoreContent.Spending) -> String? {
        spending.progress == nil ? spending.latestItem : spending.figure.caption
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
