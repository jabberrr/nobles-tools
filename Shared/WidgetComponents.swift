import SwiftUI

/// A compact empty or error state sized for widgets, standing in for `ContentUnavailableView`,
/// which widgets can't use.
struct WidgetMessage: View {
    let symbol: String
    let title: String
    var detail: String? = nil
    let colors: ThemeColors

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(colors.accent)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(colors.primary)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(colors.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shows as many of `items` as fit vertically, then a "+N more" line for the rest.
///
/// Rows keep their natural text size instead of clipping mid-line: `ViewThatFits` tries a
/// handful of row counts, from `capacity` (the most that could ever fit) down to one.
struct FittingList<Item, Row: View>: View {
    let items: [Item]
    /// The most rows this space could hold; keeps the candidate counts close together.
    let capacity: Int
    var spacing: CGFloat = 4
    /// Color of the "+N more" line, or `nil` to leave it out.
    var overflowColor: Color? = nil
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        let counts = Self.candidateCounts(total: items.count, capacity: capacity)
        ViewThatFits(in: .vertical) {
            rows(counts[0])
            rows(counts[1])
            rows(counts[2])
            rows(counts[3])
            rows(counts[4])
            rows(counts[5])
            rows(counts[6])
            rows(counts[7])
        }
    }

    private func rows(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(items.prefix(count).enumerated()), id: \.offset) { _, item in
                row(item)
            }
            if let overflowColor, count < items.count {
                Text("+\(items.count - count) more")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(overflowColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eight descending counts (`ViewThatFits` needs a fixed number of children).
    private static func candidateCounts(total: Int, capacity: Int) -> [Int] {
        let top = max(1, min(total, capacity))
        let step = max(1, (top + 7) / 8)
        return (0..<8).map { max(1, top - $0 * step) }
    }
}
