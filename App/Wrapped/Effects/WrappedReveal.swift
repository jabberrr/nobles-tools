import SwiftUI

/// How `wrappedReveal` brings a view in.
enum WrappedRevealStyle {
    /// Fades in while moving up.
    case rise
    /// Scales up from small with a bouncy spring, fading in.
    case pop
    case fade
    /// Slides in from that edge, fading in.
    case slide(Edge)
    /// Grows upward from its bottom edge, for vertical bars.
    case growUp
    /// Grows rightward from its leading edge, for horizontal bars.
    case growRight
    /// Fades in from a blur.
    case blur
}

extension View {
    /// Hidden until `isActive`, then revealed after `delay` with `style`; hidden again (without
    /// animation) when `isActive` turns false, so revisiting a page replays it. Shown at once in
    /// static mode; a plain fade under Reduce Motion.
    func wrappedReveal(_ isActive: Bool, delay: Double = 0, style: WrappedRevealStyle = .rise) -> some View {
        modifier(WrappedReveal(isActive: isActive, delay: delay, style: style))
    }
}

private struct WrappedReveal: ViewModifier {
    let isActive: Bool
    let delay: Double
    let style: WrappedRevealStyle

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: pose.blur)
            .scaleEffect(x: pose.scale.width, y: pose.scale.height, anchor: pose.anchor)
            .offset(pose.offset)
            .onChange(of: isActive, initial: true) { _, active in
                if active {
                    withAnimation(animation.delay(delay)) { isRevealed = true }
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { isRevealed = false }
                }
            }
    }

    private var isHidden: Bool {
        !(isStatic || isRevealed)
    }

    /// Growing bars stay opaque (their collapsed scale hides them) rather than fading while they grow.
    private var opacity: Double {
        guard isHidden else { return 1 }
        return style.isGrowth && !reduceMotion ? 1 : 0
    }

    private var pose: Pose {
        isHidden && !reduceMotion ? hiddenPose : Pose()
    }

    /// Where a hidden view waits, relative to where it ends up.
    private struct Pose {
        var offset = CGSize.zero
        var scale = CGSize(width: 1, height: 1)
        var anchor = UnitPoint.center
        var blur: CGFloat = 0
    }

    private var hiddenPose: Pose {
        switch style {
        case .rise:
            Pose(offset: CGSize(width: 0, height: 24))
        case .pop:
            Pose(scale: CGSize(width: 0.4, height: 0.4))
        case .fade:
            Pose()
        case .slide(let edge):
            Pose(offset: Self.offset(from: edge))
        case .growUp:
            Pose(scale: CGSize(width: 1, height: Self.collapsed), anchor: .bottom)
        case .growRight:
            Pose(scale: CGSize(width: Self.collapsed, height: 1), anchor: .leading)
        case .blur:
            Pose(blur: 12)
        }
    }

    private var animation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.3)
        }
        switch style {
        case .rise, .slide:
            return .spring(duration: 0.6, bounce: 0.2)
        case .pop:
            return .spring(duration: 0.55, bounce: 0.5)
        case .fade:
            return .easeOut(duration: 0.5)
        case .growUp, .growRight:
            return .spring(duration: 0.7, bounce: 0.15)
        case .blur:
            return .easeOut(duration: 0.7)
        }
    }

    /// A grown view's scale before it grows: not quite zero, which some renderers reject.
    private static let collapsed: CGFloat = 0.001

    private static func offset(from edge: Edge) -> CGSize {
        switch edge {
        case .top: CGSize(width: 0, height: -60)
        case .bottom: CGSize(width: 0, height: 60)
        case .leading: CGSize(width: -60, height: 0)
        case .trailing: CGSize(width: 60, height: 0)
        }
    }
}

private extension WrappedRevealStyle {
    var isGrowth: Bool {
        switch self {
        case .growUp, .growRight: true
        default: false
        }
    }
}

private struct WrappedRevealPreview: View {
    @State private var isActive = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Rise").font(.title.bold()).wrappedReveal(isActive)
            Text("Pop").font(.title.bold()).wrappedReveal(isActive, delay: 0.3, style: .pop)
            Text("Slide").font(.title.bold()).wrappedReveal(isActive, delay: 0.6, style: .slide(.leading))
            Text("Blur").font(.title.bold()).wrappedReveal(isActive, delay: 0.9, style: .blur)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.orange)
                        .frame(width: 28, height: CGFloat(40 + index * 22))
                        .wrappedReveal(isActive, delay: 1.2 + Double(index) * 0.12, style: .growUp)
                }
            }
            Capsule()
                .fill(.teal)
                .frame(width: 220, height: 14)
                .wrappedReveal(isActive, delay: 1.9, style: .growRight)
            Button(isActive ? "Reset" : "Reveal") { isActive.toggle() }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Reveals") {
    WrappedRevealPreview()
}
