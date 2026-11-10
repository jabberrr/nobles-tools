import SwiftUI

/// A surface of real crumpled foil (the `FoilTexture` photo scan), with a light sweep now and
/// then. Fills its frame, clipped to `cornerRadius`. Still in static mode and under Reduce Motion.
struct FoilSurface: View {
    private let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 0) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        FoilTextureFill()
            .overlay {
                // A pressed edge: bright where it faces the light, dark where it turns away.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.7), .white.opacity(0.1), .black.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            }
            .clipShape(shape)
            .foilShimmer(strength: FoilArt.sweepStrength)
            .accessibilityHidden(true)
    }
}

/// The foil photo filling its frame over plain silver, cropped and never stretched, lit from the
/// upper left. It's never drawn smaller than `minimumSide`, so crinkles keep their size on small
/// surfaces.
struct FoilTextureFill: View {
    var minimumSide: CGFloat = 280

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height, minimumSide)
            FoilArt.texture
                .saturation(FoilPainter.saturation)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(FoilPainter.silver)
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.3), location: 0),
                    .init(color: .white.opacity(0), location: 0.45),
                    .init(color: .black.opacity(0.2), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipped()
    }
}

/// The foil's photo and sheen, shared by everything made of it.
@MainActor
enum FoilArt {
    /// A photo scan of crumpled aluminium foil (ambientCG, CC0).
    static var texture: Image {
        Image("FoilTexture").resizable().interpolation(.high)
    }

    /// How bright the light sweeping across foil gets: softer than on plain metallic text, so
    /// the photo's crinkles show through.
    static let sweepStrength = 0.5
}

#Preview("Foil surface") {
    VStack(spacing: 24) {
        FoilSurface(cornerRadius: 16)
            .frame(height: 62)
            .overlay {
                Text("? ? ?")
                    .font(WrappedStyle.number(26))
                    .foregroundStyle(WrappedStyle.ink)
            }
        FoilSurface(cornerRadius: 12)
            .frame(width: 120, height: 40)
        FoilSurface(cornerRadius: 32)
            .frame(width: 240, height: 300)
    }
    .padding(24)
    .background(Color(hex: 0x2E1A87))
}
