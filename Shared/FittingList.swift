import SwiftUI

/// Lays out the longest run of `items` from the start that fits whole, then a "+N more" line
/// for the rest.
///
/// Rows keep their natural size instead of being cut off mid-line: `ViewThatFits` tries counts
/// from `capacity` (the most that could ever fit) down to none, and shows the first that fits.
/// Give rows no line limit, so a row that would need more lines counts as not fitting.
struct FittingPrefix<Item, Content: View>: View {
    let items: [Item]
    /// The most items this space could hold; keeps the candidate counts close together.
    let capacity: Int
    var spacing: CGFloat = 4
    /// Color of the "+N more" line, or `nil` to leave it out.
    var overflowColor: Color? = nil
    /// Lays out the items that are shown.
    @ViewBuilder let content: ([Item]) -> Content

    var body: some View {
        let counts = Self.candidateCounts(total: items.count, capacity: capacity)
        ViewThatFits(in: .vertical) {
            layout(showing: counts[0])
            layout(showing: counts[1])
            layout(showing: counts[2])
            layout(showing: counts[3])
            layout(showing: counts[4])
            layout(showing: counts[5])
            layout(showing: counts[6])
            layout(showing: counts[7])
            layout(showing: counts[8])
            layout(showing: counts[9])
        }
    }

    /// The first `count` items, then the "+N more" line if any are left out.
    private func layout(showing count: Int) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if count > 0 {
                // The rows chosen fit whole, so they keep their ideal height: a stack would
                // otherwise share its height out evenly and cut short a row that needs more.
                content(Array(items.prefix(count)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let overflowColor, count < items.count {
                Text("+\(items.count - count) more")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(overflowColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Ten counts (`ViewThatFits` needs a fixed number of children), descending to zero: every
    /// count up to nine items, and evenly spaced ones above that.
    private static func candidateCounts(total: Int, capacity: Int) -> [Int] {
        let top = max(0, min(total, capacity))
        let step = max(1, (top + 8) / 9)
        return (0..<10).map { max(0, top - $0 * step) }
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
