import SwiftUI

/// Lays out the longest run of `items` from the start that fits whole, then a "+N more" line
/// for the rest.
///
/// Rows keep their natural size instead of being cut off mid-line: every count from `capacity`
/// (the most that could ever fit) down to none is tried, and the first that fits is shown.
/// Give rows no line limit, so a row that would need more lines counts as not fitting, and pin
/// text that wraps to its ideal height (`fixedSize(horizontal: false, vertical: true)`): a stack
/// shares its height out by its own rules and can cut one row short even when all of them fit.
struct FittingPrefix<Item, Content: View>: View {
    let items: [Item]
    /// The most items this space could ever hold, which bounds the counts tried.
    let capacity: Int
    var spacing: CGFloat = 4
    /// Color of the "+N more" line, or `nil` to leave it out.
    var overflowColor: Color? = nil
    /// Lays out the items that are shown.
    @ViewBuilder let content: ([Item]) -> Content

    var body: some View {
        let most = max(0, min(items.count, capacity))
        FirstFitting(variants: Array((0...most).reversed()), axes: .vertical) { count in
            layout(showing: count)
        }
    }

    /// The first `count` items, then the "+N more" line if any are left out.
    private func layout(showing count: Int) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if count > 0 {
                content(Array(items.prefix(count)))
            }
            if let overflowColor, count < items.count {
                MoreLabel(count: items.count - count, color: overflowColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "+3 more", quietly, after a list that couldn't show everything.
struct MoreLabel: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("+\(count) more")
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
    }
}

/// A `FittingPrefix` that stacks its items in a single column.
struct FittingList<Item, Row: View>: View {
    let items: [Item]
    let capacity: Int
    var spacing: CGFloat = 4
    var overflowColor: Color? = nil
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        FittingPrefix(items: items, capacity: capacity, spacing: spacing, overflowColor: overflowColor) { shown in
            ForEach(Array(shown.enumerated()), id: \.offset) { _, item in
                row(item)
            }
        }
    }
}
