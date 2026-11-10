import SwiftUI

/// A short hint in a capsule, such as "Tap to start", pulsing gently to draw the eye. Still in
/// static mode and under Reduce Motion.
struct WrappedHint: View {
    private let text: LocalizedStringKey
    private let symbol: String

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: LocalizedStringKey, symbol: String = "hand.tap.fill") {
        self.text = text
        self.symbol = symbol
    }

    var body: some View {
        let label = Label(text, systemImage: symbol)
            .font(WrappedStyle.strongCaption)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.16), in: Capsule())
        if isStatic || reduceMotion {
            label
        } else {
            label.phaseAnimator([false, true]) { content, isDimmed in
                content
                    .opacity(isDimmed ? 0.55 : 1)
                    .scaleEffect(isDimmed ? 0.97 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        }
    }
}

#Preview("Hint") {
    WrappedHint("Tap to start")
        .foregroundStyle(.white)
        .padding(40)
        .background(Color(hex: 0x2A0A5E))
}
