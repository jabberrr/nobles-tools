import SwiftUI

/// Covers `content` in crinkled foil that tears away a little with each tap, until it's gone
/// after `tapsToUnwrap` taps.
///
/// Each tap crinkles and shakes the foil (with a haptic) and tears off a chunk near the finger,
/// bigger each time, which tumbles away while the content shows through the hole. The last tap
/// bursts off the rest, the content pops, and `onUnwrap` runs. The foil keeps swallowing taps
/// until the last pieces land, so a quick extra tap can't reach what's behind it mid-burst; after
/// that, taps pass through. `initialTaps` starts it part unwrapped, torn at fixed spots, for
/// snapshots. In static mode it draws that state without moving; under Reduce Motion pieces fade
/// instead of flying.
struct FoilWrap<Content: View>: View {
    private let tapsToUnwrap: Int
    private let onTap: (Int) -> Void
    private let onUnwrap: () -> Void
    private let content: Content

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var foil: FoilState
    /// Whether the content has popped up to full size; it sits a little small under the foil.
    @State private var isPopped: Bool

    init(
        tapsToUnwrap: Int = 5,
        initialTaps: Int = 0,
        onTap: @escaping (_ taps: Int) -> Void = { _ in },
        onUnwrap: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        let foil = FoilState(sheet: .standard, tapsToUnwrap: tapsToUnwrap, initialTaps: initialTaps)
        self.tapsToUnwrap = foil.tapsToUnwrap
        self.onTap = onTap
        self.onUnwrap = onUnwrap
        self.content = content()
        _foil = State(initialValue: foil)
        _isPopped = State(initialValue: foil.isUnwrapped)
    }

    var body: some View {
        content
            .scaleEffect(isPopped || reduceMotion ? 1 : 0.92)
            .accessibilityHidden(!foil.isUnwrapped)
            .overlay {
                // While it's here it takes every tap on it: until the last pieces have landed.
                if !foil.isUnwrapped || !foil.pieces.isEmpty {
                    foilLayer
                        .padding(-FoilSheet.overhang)
                }
            }
            .sensoryFeedback(trigger: foil.taps) { _, taps in
                taps >= tapsToUnwrap
                    ? SensoryFeedback.success
                    : SensoryFeedback.impact(flexibility: .soft, intensity: 0.9)
            }
            .task(id: foil.taps) {
                guard !foil.pieces.isEmpty else { return }
                do {
                    try await Task.sleep(for: .seconds(FoilPiece.longestFlight))
                } catch {
                    return
                }
                foil.dropLandedPieces(at: Date.now.timeIntervalSinceReferenceDate)
            }
    }

    private var foilLayer: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard proxy.size.width > 0, proxy.size.height > 0 else { return }
                    tap(at: CGPoint(x: location.x / proxy.size.width, y: location.y / proxy.size.height))
                }
        }
        .overlay {
            foilDrawing
                .allowsHitTesting(false)
        }
        .accessibilityElement()
        .accessibilityLabel("Wrapped in foil")
        .accessibilityValue(tapsLeftDescription)
        .accessibilityHint("Double-tap to tear some off.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tap(at: foil.nextPresetPoint) }
        .accessibilityHidden(foil.isUnwrapped)
    }

    @ViewBuilder private var foilDrawing: some View {
        if isStatic {
            FoilLayers(frame: frame(at: 0))
        } else {
            TimelineView(.animation(minimumInterval: foil.pieces.isEmpty ? 1.0 / 30.0 : nil, paused: isStill)) { timeline in
                FoilLayers(frame: frame(at: timeline.date.timeIntervalSinceReferenceDate))
            }
        }
    }

    /// Nothing is moving: no pieces in flight, and no idling under Reduce Motion or once unwrapped.
    private var isStill: Bool {
        foil.pieces.isEmpty && (reduceMotion || foil.isUnwrapped)
    }

    private func frame(at time: TimeInterval) -> FoilFrame {
        FoilFrame(
            sheet: .standard,
            state: foil,
            time: time,
            isIdle: !isStatic && !reduceMotion && !foil.isUnwrapped,
            reduceMotion: reduceMotion
        )
    }

    private var tapsLeftDescription: String {
        let left = tapsToUnwrap - foil.taps
        return left == 1 ? "1 tap left" : "\(left) taps left"
    }

    /// Tears off the next chunk around `point` (unit coordinates of the foil).
    private func tap(at point: CGPoint) {
        guard !foil.isUnwrapped else { return }
        foil.tap(.standard, at: point, time: Date.now.timeIntervalSinceReferenceDate)
        onTap(foil.taps)
        if foil.isUnwrapped {
            withAnimation(.spring(duration: 0.55, bounce: 0.55).delay(0.1)) { isPopped = true }
            onUnwrap()
        }
    }
}

/// One frame of the foil: the sheet, with the pieces in flight above it while there are any.
private struct FoilLayers: View {
    let frame: FoilFrame

    var body: some View {
        ZStack {
            FoilCanvas(frame: frame, layer: .sheet)
            if !frame.state.pieces.isEmpty {
                FoilCanvas(frame: frame, layer: .pieces)
            }
        }
    }
}

/// A canvas drawing one layer of the foil, reaching past the foil's frame by the layer's room.
private struct FoilCanvas: View {
    let frame: FoilFrame
    let layer: FoilFrame.Layer

    var body: some View {
        let frame = self.frame
        let layer = self.layer
        let room = layer.room
        Canvas { context, size in
            frame.draw(layer, in: context, size: size)
        }
        .padding(EdgeInsets(top: -room.top, leading: -room.leading, bottom: -room.bottom, trailing: -room.trailing))
    }
}

// MARK: - Previews

/// A stand-in for the favorite item's picture: an emoji on a soft plate.
private struct PreviewPlate: View {
    var body: some View {
        Text("🧋")
            .font(.system(size: 120))
            .frame(width: 220, height: 220)
            .background {
                Circle().fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), .white.opacity(0.25)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
            }
    }
}

private struct FoilWrapPreview: View {
    @State private var taps = 0
    @State private var wrapping = 0

    var body: some View {
        VStack(spacing: 36) {
            FoilWrap(onTap: { taps = $0 }) {
                PreviewPlate()
            }
            .id(wrapping)
            Text(taps >= 5 ? "Unwrapped!" : "Tap the foil (\(5 - taps) to go)")
                .font(.headline)
                .foregroundStyle(.white)
            Button("Wrap again") {
                taps = 0
                wrapping += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            WrappedBackground(colors: [Color(red: 0.30, green: 0.10, blue: 0.52), Color(red: 0.62, green: 0.10, blue: 0.38)])
                .ignoresSafeArea()
        }
    }
}

#Preview("Foil wrap") {
    FoilWrapPreview()
}

#Preview("Foil wrap, 0 and 3 of 5 taps (static)") {
    VStack(spacing: 40) {
        FoilWrap { PreviewPlate() }
        FoilWrap(initialTaps: 3) { PreviewPlate() }
    }
    .padding(40)
    .background(Color(red: 0.12, green: 0.22, blue: 0.45))
    .environment(\.wrappedIsStatic, true)
}
