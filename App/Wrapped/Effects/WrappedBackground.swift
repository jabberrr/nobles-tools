import SwiftUI

/// A slowly drifting gradient backdrop of large soft color blobs over a base gradient of
/// `colors` (2–4). Changing `colors` cross-fades. Fills its frame; callers add `.ignoresSafeArea()`.
///
/// The blobs only ever use `colors`, so text that contrasts with every one of them stays readable.
struct WrappedBackground: View {
    private let colors: [Color]

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The palettes on screen, bottom first: the newest fades in over the ones it replaces.
    @State private var layers: [Layer]

    init(colors: [Color]) {
        self.colors = colors
        _layers = State(initialValue: [Layer(id: 0, colors: colors)])
    }

    var body: some View {
        Group {
            if isStatic || reduceMotion {
                field(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    field(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
        .onChange(of: colors) { _, newColors in
            let layer = Layer(id: (layers.last?.id ?? 0) + 1, colors: newColors)
            withAnimation(.easeInOut(duration: 0.8)) { layers.append(layer) }
        }
        .task(id: layers.last?.id) {
            guard layers.count > 1 else { return }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            layers.removeFirst(layers.count - 1)
        }
    }

    private func field(at time: TimeInterval) -> some View {
        ZStack {
            ForEach(layers) { layer in
                BlobField(colors: layer.colors, time: time)
                    .transition(.opacity)
            }
        }
    }

    private struct Layer: Identifiable {
        let id: Int
        let colors: [Color]
    }
}

/// One palette's base gradient and drifting blobs, at one moment.
private struct BlobField: View {
    let colors: [Color]
    let time: TimeInterval

    var body: some View {
        let painter = BlobPainter(colors: colors, time: time)
        Canvas { context, size in
            painter.draw(in: &context, size: size)
        }
    }
}

/// Draws a base gradient and a few large radial blobs that wander slowly around fixed homes.
private struct BlobPainter: Sendable {
    let colors: [Color]
    let time: TimeInterval

    /// A blob's home (unit coordinates), radius (fraction of the longer side), which palette
    /// color it takes (counting from the end), its strength, and its own drift phase.
    private struct Blob: Sendable {
        let x: Double
        let y: Double
        let radius: Double
        let colorFromEnd: Int
        let opacity: Double
        let phase: Double
    }

    private static let blobs = [
        Blob(x: 0.18, y: 0.22, radius: 0.55, colorFromEnd: 1, opacity: 0.55, phase: 0),
        Blob(x: 0.86, y: 0.50, radius: 0.60, colorFromEnd: 0, opacity: 0.50, phase: 1.7),
        Blob(x: 0.28, y: 0.86, radius: 0.50, colorFromEnd: 2, opacity: 0.50, phase: 3.1),
        Blob(x: 0.78, y: 0.10, radius: 0.45, colorFromEnd: 3, opacity: 0.45, phase: 4.6),
    ]

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let palette = Self.palette(colors)
        let width = Double(size.width)
        let height = Double(size.height)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: palette),
                startPoint: .zero,
                endPoint: CGPoint(x: width, y: height)
            )
        )
        let longest = max(width, height)
        for blob in Self.blobs {
            let color = palette[palette.count - 1 - blob.colorFromEnd % palette.count]
            let x = (blob.x + 0.14 * sin(time * 0.13 + blob.phase)) * width
            let y = (blob.y + 0.10 * cos(time * 0.17 + blob.phase * 1.3)) * height
            let radius = blob.radius * longest
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(blob.opacity), color.opacity(0)]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: CGFloat(radius)
                )
            )
        }
    }

    /// At least two colors to draw with.
    private static func palette(_ colors: [Color]) -> [Color] {
        switch colors.count {
        case 0: [Color(white: 0.12), Color(white: 0.2)]
        case 1: [colors[0], colors[0]]
        default: colors
        }
    }
}

private struct WrappedBackgroundPreview: View {
    private static let palettes: [[Color]] = [
        [Color(red: 0.29, green: 0.11, blue: 0.55), Color(red: 0.75, green: 0.13, blue: 0.42)],
        [Color(red: 0.02, green: 0.30, blue: 0.40), Color(red: 0.09, green: 0.18, blue: 0.48), Color(red: 0.30, green: 0.10, blue: 0.45)],
        [Color(red: 0.55, green: 0.17, blue: 0.05), Color(red: 0.62, green: 0.08, blue: 0.20)],
    ]
    @State private var index = 0

    var body: some View {
        WrappedBackground(colors: Self.palettes[index])
            .ignoresSafeArea()
            .onTapGesture { index = (index + 1) % Self.palettes.count }
            .overlay {
                Text("Tap to change colors").font(WrappedStyle.lead).foregroundStyle(.white)
            }
    }
}

#Preview("Background") {
    WrappedBackgroundPreview()
}
