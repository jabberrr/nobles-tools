import SwiftUI

/// A row of vertical bars that grow in one after another, left to right, each with a label under
/// it and, optionally, a figure over it. The highlighted bar is drawn in the highlight color.
struct WrappedBarChart: View {
    struct Bar: Identifiable {
        let id: Int
        let value: Double
        /// Under the bar; `nil` leaves the spot blank.
        var label: String?
        /// Over the bar; `nil` shows none.
        var valueLabel: String?
        var isHighlighted = false
    }

    let bars: [Bar]
    let isActive: Bool
    /// The tallest bar's height.
    var height: CGFloat = 160
    var spacing: CGFloat = 8
    var maxBarWidth: CGFloat = 52
    /// When the first bar starts growing, and how long each waits after the one before.
    var delay: Double = 0
    var stagger: Double = 0.1

    var body: some View {
        let peak = bars.map(\.value).max() ?? 0
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(bars.enumerated()), id: \.element.id) { position, bar in
                column(bar, fraction: peak > 0 ? bar.value / peak : 0, delay: delay + stagger * Double(position))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// The figure (if any), the bar, then its label. Figures and labels sit in fixed-height
    /// slots, so one wider than its bar overhangs it instead of widening the column.
    private func column(_ bar: Bar, fraction: Double, delay: Double) -> some View {
        VStack(spacing: 6) {
            if let valueLabel = bar.valueLabel {
                slot(height: 16) {
                    Text(valueLabel)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(bar.isHighlighted ? WrappedStyle.highlight : Color.white)
                }
                .wrappedReveal(isActive, delay: delay + 0.3, style: .fade)
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(barColor(for: bar))
                .frame(height: bar.value > 0 ? max(8, height * CGFloat(fraction)) : 3)
                .wrappedReveal(isActive, delay: delay, style: .growUp)
            slot(height: 14) {
                Text(bar.label ?? "")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(bar.isHighlighted ? WrappedStyle.highlight : WrappedStyle.secondary)
            }
        }
        .frame(maxWidth: maxBarWidth)
    }

    private func slot<Label: View>(height: CGFloat, @ViewBuilder text: () -> Label) -> some View {
        Color.clear
            .frame(height: height)
            .overlay {
                text()
                    .fixedSize()
            }
    }

    private func barColor(for bar: Bar) -> Color {
        if bar.isHighlighted {
            return WrappedStyle.highlight
        }
        return Color.white.opacity(bar.value > 0 ? 0.45 : 0.2)
    }
}
