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

/// Lays out the longest run of `items` from the start that fits vertically, then a "+N more"
/// line for the rest.
///
/// Rows keep their natural text size instead of clipping mid-line: `ViewThatFits` tries a
/// handful of counts, from `capacity` (the most that could ever fit) down to one.
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
        }
    }

    /// The first `count` items, then the "+N more" line if any are left out.
    private func layout(showing count: Int) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content(Array(items.prefix(count)))
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

/// A circular progress track, filled clockwise from the top.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    let colors: ThemeColors

    var body: some View {
        ZStack {
            Circle()
                .stroke(colors.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(colors.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// A horizontal capsule progress bar.
struct ProgressBar: View {
    let progress: Double
    let colors: ThemeColors

    var body: some View {
        GeometryReader { proxy in
            let filled = progress > 0 ? max(proxy.size.height, proxy.size.width * CGFloat(progress)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(colors.track)
                Capsule().fill(colors.accent).frame(width: filled)
            }
        }
    }
}
