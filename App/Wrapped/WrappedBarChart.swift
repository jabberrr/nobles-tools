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
        // Room for the figure over the tallest bar.
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func column(_ bar: Bar, fraction: Double, delay: Double) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(barColor(for: bar))
                .frame(height: bar.value > 0 ? max(8, height * CGFloat(fraction)) : 3)
                .wrappedReveal(isActive, delay: delay, style: .growUp)
                .overlay(alignment: .top) {
                    if let valueLabel = bar.valueLabel {
                        Text(valueLabel)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(bar.isHighlighted ? WrappedStyle.highlight : Color.white)
                            .fixedSize()
                            .alignmentGuide(.top) { $0[.bottom] + 6 }
                            .wrappedReveal(isActive, delay: delay + 0.3, style: .fade)
                    }
                }
            // A fixed-height slot, so labels wider than their bar overhang it instead of
            // widening the column.
            Color.clear
                .frame(height: 14)
                .overlay {
                    Text(bar.label ?? "")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(bar.isHighlighted ? WrappedStyle.highlight : WrappedStyle.secondary)
                        .fixedSize()
                }
        }
        .frame(maxWidth: maxBarWidth)
    }

    private func barColor(for bar: Bar) -> Color {
        if bar.isHighlighted {
            return WrappedStyle.highlight
        }
        return Color.white.opacity(bar.value > 0 ? 0.45 : 0.2)
    }
}
