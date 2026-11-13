import SwiftUI

/// A hairline across the page: what separates rows now that pages set their stats as type
/// rather than in boxes. A vertical one separates columns, as tall as the row it's in.
struct WrappedRule: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
            .accessibilityHidden(true)
    }
}

/// A stat set as type, with no box around it: a small uppercase label, a big figure in the
/// highlight color, and an optional caption under it, all on a left edge.
struct WrappedStat<Figure: View>: View {
    let label: String
    var caption: String?
    /// The figure's point size.
    var size: CGFloat = 30
    @ViewBuilder let figure: Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WrappedCardLabel(label)
            figure
                .font(WrappedStyle.number(size))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let caption {
                Text(caption)
                    .font(WrappedStyle.caption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
