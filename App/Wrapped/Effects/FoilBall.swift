import SwiftUI

/// A ball of crumpled foil, lit like a sphere: what the wrap turns into once it's off.
struct FoilBall: View {
    let diameter: CGFloat

    var body: some View {
        let creases = FoilBallShape.creases(diameter: diameter)
        // The whole photo squeezed into the ball, so its crinkles come out tight.
        FoilTextureFill(minimumSide: 0)
            .frame(width: diameter, height: diameter)
            .overlay {
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.55), location: 0),
                        .init(color: .white.opacity(0), location: 0.4),
                        .init(color: .black.opacity(0.5), location: 1),
                    ],
                    center: UnitPoint(x: 0.36, y: 0.3),
                    startRadius: 0,
                    endRadius: diameter * 0.8
                )
            }
            .overlay {
                creases
                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    .offset(x: 0.6, y: 0.8)
                creases
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.7)
            }
            .clipShape(FoilBallShape.outline(diameter: diameter))
            .shadow(color: .black.opacity(0.35), radius: diameter * 0.08, y: diameter * 0.06)
            .accessibilityHidden(true)
    }
}

/// The ball's lumpy outline and the creases across it, in a `diameter`-sized square.
private enum FoilBallShape {
    private static let lumps = 12

    static func outline(diameter: CGFloat) -> Path {
        var random = SeededRandom(seed: 0xBA11)
        let radius = Double(diameter) / 2
        let corners = (0..<lumps).map { index in
            let angle = Double(index) / Double(lumps) * 2 * Double.pi
            let reach = radius * random.value(in: 0.84...1)
            return CGPoint(x: radius + cos(angle) * reach, y: radius + sin(angle) * reach)
        }
        // A smooth curve through the midpoints between corners, bending toward each corner.
        var path = Path()
        path.move(to: midpoint(corners[lumps - 1], corners[0]))
        for index in 0..<lumps {
            path.addQuadCurve(to: midpoint(corners[index], corners[(index + 1) % lumps]), control: corners[index])
        }
        path.closeSubpath()
        return path
    }

    /// A few zigzag folds across the ball.
    static func creases(diameter: CGFloat) -> Path {
        var random = SeededRandom(seed: 0xC2EA5E)
        let size = Double(diameter)
        var path = Path()
        for _ in 0..<5 {
            path.move(to: CGPoint(x: size * random.value(in: 0.1...0.9), y: size * random.value(in: 0.1...0.9)))
            for _ in 0..<3 {
                path.addLine(to: CGPoint(x: size * random.value(in: 0.1...0.9), y: size * random.value(in: 0.1...0.9)))
            }
        }
        return path
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

#Preview("Foil ball") {
    HStack(spacing: 24) {
        FoilBall(diameter: 60)
        FoilBall(diameter: 120)
    }
    .padding(40)
    .background(Color(hex: 0x2E1A87))
}
