import SwiftUI

/// Columns of stacked blocks that grow up one after another, left to right: each column's parts
/// from the bottom in `colors`, with a label under it and, optionally, a figure over it. Heights
/// are to scale, the tallest column filling the height the chart is given. Columns too few to
/// fill the width at their widest start at its leading edge.
struct WrappedStackedColumns: View {
    struct Column: Identifiable {
        let id: Int
        /// Each part's value, in the order of `colors`; a value below zero draws nothing.
        let values: [Double]
        /// Under the column; `nil` leaves the spot blank.
        var label: String?
        /// Over the column; `nil` shows none.
        var figure: String?

        /// What the column stacks up to: its positive values.
        var total: Double {
            values.reduce(0) { $0 + max($1, 0) }
        }
    }

    let columns: [Column]
    let colors: [Color]
    let isActive: Bool
    var spacing: CGFloat = 8
    var maxColumnWidth: CGFloat = 52
    /// Where a label sits under its column: centered on it, or (`.leading`) starting at its edge
    /// and running on past it.
    var labelAlignment: Alignment = .center
    /// When the first column starts growing, and how long each waits after the one before.
    var delay: Double = 0
    var stagger: Double = 0.1

    private static let figureHeight: CGFloat = 16
    private static let labelHeight: CGFloat = 14
    /// Between a column and its figure or label.
    private static let slotGap: CGFloat = 4
    /// Between the blocks of a column.
    private static let blockGap: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let plotHeight = max(0, proxy.size.height - reservedHeight)
            let peak = columns.map(\.total).max() ?? 0
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { position, column in
                    self.column(
                        column,
                        height: peak > 0 ? plotHeight * CGFloat(column.total / peak) : 0,
                        delay: delay + stagger * Double(position)
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
        }
        .accessibilityHidden(true)
    }

    private var hasFigures: Bool {
        columns.contains { $0.figure != nil }
    }

    /// The height taken by the figures' and labels' slots.
    private var reservedHeight: CGFloat {
        (hasFigures ? Self.figureHeight + Self.slotGap : 0) + Self.slotGap + Self.labelHeight
    }

    /// The figure's slot (if any column has one), the blocks, then the label's slot. Figures and
    /// labels overhang their slots rather than widen the column.
    private func column(_ column: Column, height: CGFloat, delay: Double) -> some View {
        VStack(spacing: Self.slotGap) {
            if hasFigures {
                slot(height: Self.figureHeight, alignment: .bottom) {
                    Text(column.figure ?? "")
                        .font(WrappedStyle.chartFigure)
                }
                .wrappedReveal(isActive, delay: delay + 0.3, style: .fade)
            }
            blocks(column, height: height)
                .wrappedReveal(isActive, delay: delay, style: .growUp)
            slot(height: Self.labelHeight, alignment: labelAlignment) {
                Text(column.label ?? "")
                    .font(WrappedStyle.chartLabel)
                    .foregroundStyle(WrappedStyle.secondary)
            }
        }
        .frame(maxWidth: maxColumnWidth)
    }

    /// The column's positive parts as blocks, the first at the bottom, together `height` tall; a
    /// faint baseline for a column with nothing.
    @ViewBuilder
    private func blocks(_ column: Column, height: CGFloat) -> some View {
        let parts = column.values.indices.filter { column.values[$0] > 0 }
        if parts.isEmpty {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.white.opacity(0.25))
                .frame(height: 3)
        } else {
            let blockHeight = max(0, height - Self.blockGap * CGFloat(parts.count - 1))
            VStack(spacing: Self.blockGap) {
                ForEach(parts.reversed(), id: \.self) { part in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(colors.indices.contains(part) ? colors[part] : Color.white)
                        .frame(height: max(2, blockHeight * CGFloat(column.values[part] / column.total)))
                }
            }
        }
    }

    private func slot<Label: View>(height: CGFloat, alignment: Alignment, @ViewBuilder text: () -> Label) -> some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: alignment) {
                text()
                    .fixedSize()
            }
    }
}

#Preview {
    WrappedStackedColumns(
        columns: [
            .init(id: 0, values: [41.5, 28], label: "Mon", figure: "$70"),
            .init(id: 1, values: [55, 37.25], label: "Tue", figure: "$92"),
            .init(id: 2, values: [31, 54.5], label: "Wed", figure: "$86"),
            .init(id: 3, values: [0, 0], label: "Thu"),
            .init(id: 4, values: [37.25, 19], label: "Fri", figure: "$56"),
        ],
        colors: [WrappedStyle.highlight, Color(hex: 0xA5F3FC)],
        isActive: true
    )
    .frame(height: 160)
    .padding(24)
    .foregroundStyle(.white)
    .background(Color(hex: 0xB42318))
}
