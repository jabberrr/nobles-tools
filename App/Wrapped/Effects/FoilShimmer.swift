import SwiftUI

enum WrappedFX {
    /// A silver-and-iridescent metallic gradient, for `foregroundStyle` on titles.
    static var foilGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.80, green: 0.82, blue: 0.87), location: 0),
                .init(color: Color(red: 0.98, green: 0.98, blue: 1.00), location: 0.2),
                .init(color: Color(red: 0.72, green: 0.75, blue: 0.81), location: 0.4),
                .init(color: Color(red: 0.96, green: 0.84, blue: 0.94), location: 0.58),
                .init(color: Color(red: 0.80, green: 0.93, blue: 0.98), location: 0.76),
                .init(color: Color(red: 0.90, green: 0.91, blue: 0.95), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    /// A metallic highlight sweeping across the view's opaque pixels every few seconds (masked to
    /// the view), for foil-ish titles and teasers. Still in static mode / Reduce Motion.
    func foilShimmer(isActive: Bool = true) -> some View {
        modifier(FoilShimmer(isActive: isActive))
    }
}

private struct FoilShimmer: ViewModifier {
    let isActive: Bool

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive && !isStatic && !reduceMotion {
                    TimelineView(SweepSchedule()) { timeline in
                        Self.highlight(at: timeline.date.timeIntervalSinceReferenceDate)
                    }
                    .blendMode(.sourceAtop)
                    .allowsHitTesting(false)
                }
            }
            .compositingGroup()
    }

    /// A diagonal band of light crossing the view, or nothing between sweeps.
    private static func highlight(at time: TimeInterval) -> LinearGradient {
        let progress = Sweep.elapsed(at: time) / Sweep.duration
        let eased = progress < 1 ? progress * progress * (3 - 2 * progress) : 2
        let center = -0.6 + 2.2 * eased
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0), location: 0.38),
                .init(color: .white.opacity(0.85), location: 0.5),
                .init(color: .white.opacity(0), location: 0.62),
            ],
            startPoint: UnitPoint(x: center - 0.6, y: 0),
            endPoint: UnitPoint(x: center + 0.6, y: 1)
        )
    }
}

/// The shimmer's rhythm: a sweep crossing in `duration` seconds, starting every `period` seconds.
private enum Sweep {
    static let period = 3.4
    static let duration = 1.1
    /// Between frames while a sweep crosses.
    static let frameInterval = 1.0 / 30.0

    /// Seconds since the latest sweep started.
    static func elapsed(at time: TimeInterval) -> TimeInterval {
        time.truncatingRemainder(dividingBy: period)
    }

    /// From a frame at `date` to the next: one frame mid-sweep (the first past the end draws the
    /// band gone), else until the next sweep starts.
    static func wait(after date: Date) -> TimeInterval {
        let elapsed = Self.elapsed(at: date.timeIntervalSinceReferenceDate)
        return elapsed < duration ? frameInterval : max(period - elapsed, frameInterval)
    }
}

/// Redraws the shimmer 30 times a second while a sweep crosses, then not again until the next.
private struct SweepSchedule: TimelineSchedule {
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(upcoming: startDate)
    }

    struct Entries: Sequence, IteratorProtocol {
        var upcoming: Date

        mutating func next() -> Date? {
            let date = upcoming
            upcoming = date.addingTimeInterval(Sweep.wait(after: date))
            return date
        }
    }
}

#Preview("Foil shimmer") {
    VStack(spacing: 16) {
        Text("Cafe Wrapped")
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(WrappedFX.foilGradient)
            .foilShimmer()
        RoundedRectangle(cornerRadius: 20)
            .fill(WrappedFX.foilGradient)
            .frame(width: 240, height: 64)
            .overlay {
                Text("???").font(.title.bold()).foregroundStyle(.black.opacity(0.4))
            }
            .foilShimmer()
    }
    .padding(40)
    .background(.indigo)
}
