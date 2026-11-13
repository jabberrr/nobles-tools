import SwiftUI

/// A face of the foil filling the stage, to be cut to shape: the shiny outside, puffed up and
/// lumpy around the bundle's middle, or the duller inside, for foil folded back.
struct FoilFinish: View {
    enum Face {
        case outside, inside
    }

    let face: Face
    let geometry: FoilGeometry

    var body: some View {
        FoilTextureFill(minimumSide: max(geometry.size.width, geometry.size.height), isTurned: face == .inside)
            .overlay {
                switch face {
                case .outside:
                    ZStack {
                        puff
                        ForEach(Self.lumps.indices, id: \.self) { index in
                            lump(Self.lumps[index], isRaised: index.isMultiple(of: 2))
                        }
                    }
                case .inside:
                    // Matte, and turned the other way to the light.
                    LinearGradient(
                        colors: [.white.opacity(0.1), .black.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
    }

    /// Brightest above and left of the bundle's middle, darker out to its edges.
    private var puff: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(0.24), location: 0),
                .init(color: .white.opacity(0), location: 0.45),
                .init(color: .black.opacity(0.32), location: 1),
            ],
            center: unitPoint(geometry.point(CGVector(dx: -0.12, dy: -0.16))),
            startRadius: 0,
            endRadius: geometry.radius * 0.95
        )
    }

    /// A soft bulge catching the light, or a dip in shade.
    private func lump(_ lump: Lump, isRaised: Bool) -> some View {
        let color = isRaised ? Color.white : Color.black
        return RadialGradient(
            colors: [color.opacity(0.14), color.opacity(0)],
            center: unitPoint(geometry.point(lump.center)),
            startRadius: 0,
            endRadius: geometry.radius * lump.size
        )
    }

    private func unitPoint(_ point: CGPoint) -> UnitPoint {
        UnitPoint(x: point.x / max(geometry.size.width, 1), y: point.y / max(geometry.size.height, 1))
    }

    /// A lump's middle and size, in radii from the bundle's middle.
    private struct Lump {
        let center: CGVector
        let size: CGFloat
    }

    private static let lumps: [Lump] = {
        var random = SeededRandom(seed: 0x104B5)
        return (0..<5).map { _ in
            let center = CGVector(dx: random.value(in: -0.5...0.5), dy: random.value(in: -0.5...0.5))
            return Lump(center: center, size: random.value(in: 0.22...0.38))
        }
    }()
}
