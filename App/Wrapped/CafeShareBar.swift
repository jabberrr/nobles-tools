import SwiftUI
import NoblesKit

/// Each group's share of spending, side by side in one bar in its color, growing in from the left
/// one after another.
struct CafeShareBar: View {
    let breakdown: CafeWrapped.CafeBreakdown
    let isActive: Bool
    var delay: Double = 0

    private static let height: CGFloat = 18
    private static let gap: CGFloat = 3

    var body: some View {
        let groups = breakdown.groups
        let colors = breakdown.colors
        let shown = groups.indices.filter { groups[$0].share > 0 }
        let sum = shown.reduce(0) { $0 + groups[$1].share }
        GeometryReader { proxy in
            let width = max(0, proxy.size.width - Self.gap * CGFloat(shown.count - 1))
            HStack(spacing: Self.gap) {
                ForEach(Array(shown.enumerated()), id: \.element) { position, index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(colors[index])
                        .frame(width: max(2, width * CGFloat(groups[index].share / sum)))
                        .wrappedReveal(isActive, delay: delay + 0.25 * Double(position), style: .growRight)
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }
}
