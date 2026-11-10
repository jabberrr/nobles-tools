import SwiftUI

/// Text that counts from zero up to `value` once `isActive` turns true (after `delay`), easing out
/// over `duration`; shows `format(value)` exactly at the end, and at once in static mode. Resets to
/// zero when `isActive` turns false. Style it with ordinary modifiers (`.font`, `.monospacedDigit()`).
struct CountingText: View {
    private let value: Double
    private let isActive: Bool
    private let duration: Double
    private let delay: Double
    private let format: (Double) -> String

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the running count starts (after its delay); `nil` while inactive.
    @State private var countStart: Date?
    @State private var isFinished = false

    init(
        _ value: Double,
        isActive: Bool,
        duration: Double = 1.4,
        delay: Double = 0,
        format: @escaping (Double) -> String
    ) {
        self.value = value
        self.isActive = isActive
        self.duration = duration
        self.delay = delay
        self.format = format
    }

    var body: some View {
        Group {
            if isStatic || isFinished {
                Text(format(value))
            } else if let countStart {
                TimelineView(.animation) { timeline in
                    Text(format(value * progress(at: timeline.date, from: countStart)))
                }
            } else {
                Text(format(0))
            }
        }
        .accessibilityLabel(format(value))
        .onChange(of: isActive, initial: true) { _, active in
            isFinished = false
            countStart = active ? Date.now.addingTimeInterval(delay) : nil
        }
        .task(id: countStart) {
            guard let countStart else { return }
            let remaining = countStart.timeIntervalSinceNow + countDuration
            do {
                try await Task.sleep(for: .seconds(max(0, remaining)))
            } catch {
                return
            }
            isFinished = true
        }
    }

    /// Under Reduce Motion the number appears whole instead of counting.
    private var countDuration: Double {
        reduceMotion ? 0 : duration
    }

    /// How far the count has come at `date`, eased out: 0 until `start`, exactly 1 at the end.
    private func progress(at date: Date, from start: Date) -> Double {
        let elapsed = date.timeIntervalSince(start)
        guard countDuration > 0 else { return elapsed >= 0 ? 1 : 0 }
        let linear = min(max(elapsed / countDuration, 0), 1)
        return 1 - pow(1 - linear, 3)
    }
}

private struct CountingTextPreview: View {
    @State private var isActive = false

    var body: some View {
        VStack(spacing: 24) {
            CountingText(287.5, isActive: isActive) { $0.formatted(.currency(code: "USD")) }
                .font(WrappedStyle.number(64))
                .monospacedDigit()
            CountingText(172, isActive: isActive, delay: 0.4) { "\(Int($0.rounded())) purchases" }
                .font(WrappedStyle.lead)
            Button(isActive ? "Reset" : "Count") { isActive.toggle() }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Counting text") {
    CountingTextPreview()
}
