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
    /// Never show a lone "+N more": when not even one item fits with it, show the first item
    /// alone, and failing that nothing (for a list under a figure, where a bare count reads as
    /// broken).
    var hidesOverflowWhenEmpty: Bool = false
    /// Lays out the items that are shown.
    @ViewBuilder let content: ([Item]) -> Content

    var body: some View {
        FirstFitting(variants: layouts, axes: .vertical) { layout in
            self.layout(showing: layout.count, withOverflow: layout.showsOverflow)
        }
    }

    /// The layouts to try, most generous first: each count down to none, with "+N more" for any
    /// left out; or, when a bare count isn't wanted, ending with one item alone and then nothing.
    private var layouts: [(count: Int, showsOverflow: Bool)] {
        let most = max(0, min(items.count, capacity))
        var layouts = stride(from: most, through: hidesOverflowWhenEmpty ? 1 : 0, by: -1)
            .map { (count: $0, showsOverflow: overflowColor != nil && $0 < items.count) }
        if hidesOverflowWhenEmpty {
            if layouts.last?.showsOverflow == true {
                layouts.append((count: 1, showsOverflow: false))
            }
            layouts.append((count: 0, showsOverflow: false))
        }
        return layouts
    }

    /// The first `count` items, then the "+N more" line for the rest when `withOverflow`.
    private func layout(showing count: Int, withOverflow: Bool) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if count > 0 {
                content(Array(items.prefix(count)))
            }
            if withOverflow, let overflowColor {
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
    var hidesOverflowWhenEmpty: Bool = false
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        FittingPrefix(
            items: items,
            capacity: capacity,
            spacing: spacing,
            overflowColor: overflowColor,
            hidesOverflowWhenEmpty: hidesOverflowWhenEmpty
        ) { shown in
            ForEach(Array(shown.enumerated()), id: \.offset) { _, item in
                row(item)
            }
        }
    }
}
