import SwiftUI
import NoblesKit

/// The featured dish in large type, under its station's name. Steps down a text size, rather
/// than cutting the name off, when it doesn't fit; only at the smallest size is it cut short.
struct FeaturedDishView: View {
    let dish: Dish
    /// `.large` for the large widget's card, `.regular` elsewhere.
    var prominence = Prominence.regular
    let showsStation: Bool
    let colors: ThemeColors

    enum Prominence {
        case regular
        case large
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            layout(font: prominence == .large ? .title3.weight(.semibold) : .headline)
            layout(font: prominence == .large ? .headline : .subheadline.weight(.semibold))
            layout(font: .footnote.weight(.semibold), canCutShort: true)
        }
    }

    /// The station over the dish. Unless `canCutShort`, the name keeps its ideal height: this
    /// layout is only shown when it fits whole.
    private func layout(font: Font, canCutShort: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if showsStation, !dish.station.isEmpty {
                Eyebrow(symbol: dish.symbol, text: dish.station, colors: colors)
                    .lineLimit(1)
            }
            Text(dish.item.name)
                .font(font)
                .foregroundStyle(colors.primary)
                .fixedSize(horizontal: false, vertical: !canCutShort)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A dish after its station's icon, for lists without station names.
struct CompactDishRow: View {
    let dish: Dish
    /// Hidden for a dish that follows another from the same station, keeping the space.
    var showsIcon = true
    var font: Font = .caption.weight(.medium)
    let colors: ThemeColors

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: dish.symbol)
                .symbolVariant(.fill)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(colors.accent)
                .frame(width: 14)
                .opacity(showsIcon ? 1 : 0)
            Text(dish.item.name)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Dishes by station: in one column, or two, in larger type when they all fit; otherwise in two
/// columns of smaller type, as many as fit whole, then "+N more" for the rest.
struct StationColumns: View {
    let stations: [MenuSection]
    let showsStations: Bool
    let colors: ThemeColors

    var body: some View {
        let rows = DishRow.rows(of: stations)
        ViewThatFits(in: .vertical) {
            column(rows, font: .subheadline)
            columns(rows, font: .subheadline)
            FittingPrefix(items: rows, capacity: 14, spacing: 8, overflowColor: colors.secondary) { shown in
                columns(shown, font: .footnote)
            }
        }
    }

    private func columns(_ rows: [DishRow], font: Font) -> some View {
        let halves = DishRow.split(rows)
        return HStack(alignment: .top, spacing: 14) {
            column(halves.left, font: font)
            column(halves.right, font: font)
        }
    }

    private func column(_ rows: [DishRow], font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if showsStations {
                    VStack(alignment: .leading, spacing: 2) {
                        if row.startsSection, !row.section.isEmpty {
                            Eyebrow(symbol: StationSymbol.name(for: row.section), text: row.section, colors: colors)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, index == 0 ? 0 : 6)
                        }
                        Text(row.item.name)
                            .font(font)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    CompactDishRow(
                        dish: Dish(item: row.item, station: row.section),
                        showsIcon: row.startsSection,
                        font: font,
                        colors: colors
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A dish laid out in station columns, with the station it came from.
private struct DishRow {
    var section: String
    var item: MenuItem
    /// Whether this is the first dish shown from its station, so the station's name goes above it.
    var startsSection: Bool

    /// Every dish in `sections`, in order.
    static func rows(of sections: [MenuSection]) -> [DishRow] {
        sections.flatMap { section in
            section.items.enumerated().map { index, item in
                DishRow(section: section.title, item: item, startsSection: index == 0)
            }
        }
    }

    /// Splits `rows` into two columns at the station boundary nearest the middle. When that
    /// boundary would leave the columns lopsided, it splits mid-station instead, and the right
    /// column repeats the station's name.
    static func split(_ rows: [DishRow]) -> (left: [DishRow], right: [DishRow]) {
        guard rows.count > 1 else { return (rows, []) }
        let middle = (rows.count + 1) / 2
        let boundaries = rows.indices.filter { $0 > 0 && rows[$0].startsSection }
        var cut = middle
        if let nearest = boundaries.min(by: { abs($0 - middle) < abs($1 - middle) }),
           abs(nearest - middle) <= max(1, rows.count / 4) {
            cut = nearest
        }
        var right = Array(rows[cut...])
        right[0].startsSection = true
        return (Array(rows[..<cut]), right)
    }
}
