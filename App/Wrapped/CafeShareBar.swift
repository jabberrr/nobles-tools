import SwiftUI

/// Each part's share of spending, side by side in one bar in its color, growing in from the left
/// one after another.
struct CafeShareBar: View {
    let parts: [CafeBreakdown.Part]
    let isActive: Bool
    var delay: Double = 0

    private static let height: CGFloat = 18
    private static let gap: CGFloat = 3

    var body: some View {
        let shown = parts.filter { $0.share > 0 }
        let sum = shown.reduce(0) { $0 + $1.share }
        GeometryReader { proxy in
            let width = max(0, proxy.size.width - Self.gap * CGFloat(shown.count - 1))
            HStack(spacing: Self.gap) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { position, part in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(part.color)
                        .frame(width: max(2, width * CGFloat(part.share / sum)))
                        .wrappedReveal(isActive, delay: delay + 0.25 * Double(position), style: .growRight)
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }
}
