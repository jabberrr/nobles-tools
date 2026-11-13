import SwiftUI

/// A surface of real crumpled foil (the `FoilTexture` photo scan), with a light sweep now and
/// then while `isShimmering`. Anything stamped into it (such as a `FoilStamp`) lies on the foil,
/// under its edge and its sweep. Fills its frame, clipped to `cornerRadius`. Still in static mode
/// and under Reduce Motion.
struct FoilSurface<Stamp: View>: View {
    private let cornerRadius: CGFloat
    private let isShimmering: Bool
    private let stamp: Stamp

    /// - Parameter stamp: What's pressed into the foil, laid out in the surface's frame.
    init(cornerRadius: CGFloat = 0, isShimmering: Bool = true, @ViewBuilder stamp: () -> Stamp) {
        self.cornerRadius = cornerRadius
        self.isShimmering = isShimmering
        self.stamp = stamp()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        FoilTextureFill()
            .overlay { stamp }
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
            .foilShimmer(isActive: isShimmering, strength: FoilArt.sweepStrength)
            .accessibilityHidden(true)
    }
}

extension FoilSurface where Stamp == EmptyView {
    /// Plain foil, with nothing stamped into it.
    init(cornerRadius: CGFloat = 0, isShimmering: Bool = true) {
        self.init(cornerRadius: cornerRadius, isShimmering: isShimmering) { EmptyView() }
    }
}

/// The foil photo filling its frame over plain silver, cropped and never stretched, lit from the
/// upper left. It's never drawn smaller than `minimumSide`, so crinkles keep their size on small
/// surfaces. `isTurned` turns and mirrors it, for the foil's other face.
struct FoilTextureFill: View {
    var minimumSide: CGFloat = 280
    var isTurned = false

    var body: some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height, minimumSide)
            FoilArt.texture
                .saturation(FoilArt.saturation)
                .frame(width: side, height: side)
                .rotationEffect(.degrees(isTurned ? 90 : 0))
                .scaleEffect(x: isTurned ? -1 : 1, y: 1)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(FoilArt.silver)
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

/// The foil's photo, color and sheen, shared by everything made of it.
@MainActor
enum FoilArt {
    /// A photo of crumpled tin foil: cropped from "Crumpled Tin Foil" by Kevin M. Gill (Wikimedia
    /// Commons, CC BY 4.0), its light evened out.
    static var texture: Image {
        Image("FoilTexture").resizable().interpolation(.high)
    }

    /// How much of the photo's color is kept, so the foil reads as silver.
    static let saturation = 0.25
    /// The foil's color under the photo.
    static let silver = Color(white: 0.78)
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
