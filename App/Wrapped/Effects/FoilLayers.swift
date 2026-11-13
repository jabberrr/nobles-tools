import SwiftUI

/// The foil at one openness, filling the stage: a puffy bundle over the item with a hole torn in
/// it, the foil folded back around the hole, and the shade it all casts on the item inside. The
/// tear's shapes animate with `openness`, so the hole tears wider and the fold rolls back.
struct FoilLayers<Silhouette: View>: View {
    let silhouette: Silhouette
    let geometry: FoilGeometry
    let openness: Double

    var body: some View {
        let unit = geometry.unit
        ZStack {
            holeShade
            foil
                .shadow(color: .black.opacity(0.35), radius: 5 * unit, y: 3 * unit)
        }
        // The bundle loosens a little as it opens.
        .scaleEffect(1 + 0.03 * openness)
    }

    /// The bundle with its hole and fold, lit from the upper left.
    private var foil: some View {
        let unit = geometry.unit
        return ZStack {
            FoilFinish(face: .outside, geometry: geometry)
                .overlay { edge(.black.opacity(0.4), shift: CGSize(width: -2.5 * unit, height: -3.5 * unit), blur: 3 * unit) }
                .overlay { edge(.white.opacity(0.6), shift: CGSize(width: 1.5 * unit, height: 2 * unit), blur: unit) }
                .overlay { creases(FoilBundleShape(part: .creases), width: 2.5 * unit, blur: 1.2 * unit) }
            fold
            // The hole's edge catching the light: the torn edge, then the fold's crest, brightest
            // on the far side of the hole, where it turns toward the light.
            tear(.hole)
                .stroke(Self.crestLight(from: 0.35, to: 0.95), lineWidth: 2.5 * unit)
        }
        .foilCutout { tear(.hole) }
        .mask { bundle() }
        .foilShimmer(strength: FoilArt.sweepStrength)
    }

    /// The foil folded back around the hole: its duller inside, rolled over at the crest, darker
    /// toward its free edge, wrinkled, and casting a shadow on the foil beneath.
    private var fold: some View {
        let unit = geometry.unit
        return FoilFinish(face: .inside, geometry: geometry)
            .overlay {
                tear(.fold)
                    .stroke(Color.black.opacity(0.28), lineWidth: 8 * unit)
                    .blur(radius: 3 * unit)
            }
            .overlay { creases(tear(.foldCreases), width: 1.6 * unit, blur: 0.5 * unit) }
            .overlay {
                tear(.hole)
                    .stroke(Self.crestLight(from: 0.15, to: 0.45), lineWidth: 8 * unit)
                    .blur(radius: 2 * unit)
            }
            .mask { tear(.fold) }
            .shadow(color: .black.opacity(0.4), radius: 2.5 * unit, x: 0.8 * unit, y: 1.5 * unit)
    }

    /// The shade the foil casts on the item inside the hole, deepest under its upper left edge.
    private var holeShade: some View {
        let unit = geometry.unit
        return tear(.hole)
            .stroke(Color.black.opacity(0.45), lineWidth: 10 * unit)
            .blur(radius: 4 * unit)
            .offset(x: unit, y: 2 * unit)
            .mask { tear(.hole) }
    }

    /// `color` along the bundle's edges that face away from `shift`: wherever the bundle lies
    /// outside its own outline moved by `shift`.
    private func edge(_ color: Color, shift: CGSize, blur: CGFloat) -> some View {
        color
            .foilCutout { bundle(copies: 8).offset(shift) }
            .blur(radius: blur)
    }

    /// Folds pressed into the foil: a soft shadow with a bright ridge beside it.
    private func creases<Lines: Shape>(_ lines: Lines, width: CGFloat, blur: CGFloat) -> some View {
        let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        let ridge = StrokeStyle(lineWidth: width / 2, lineCap: .round, lineJoin: .round)
        return ZStack {
            lines.stroke(Color.black.opacity(0.4), style: style)
                .blur(radius: blur)
                .offset(x: width * 0.4, y: width * 0.5)
            lines.stroke(Color.white.opacity(0.6), style: ridge)
                .blur(radius: blur / 2)
        }
    }

    /// The bundle's shape: its lumpy outline, taking in the item grown by `FoilBundle.cover`.
    /// Fewer stamps do for the edges' shading.
    private func bundle(copies: Int = 12) -> some View {
        ZStack {
            FoilBundleShape(part: .outline)
            GrownSilhouette(
                silhouette: silhouette,
                geometry: geometry,
                outline: FoilOutline(growth: FoilBundle.cover * geometry.unit, rumple: 0.2, seed: 0xC0E2, copies: copies)
            )
        }
    }

    private func tear(_ part: FoilTearShape.Part) -> FoilTearShape {
        FoilTearShape(openness: openness, part: part)
    }

    /// Light along the crest, from `start` opacity at the upper left to `end` at the lower right.
    private static func crestLight(from start: Double, to end: Double) -> LinearGradient {
        LinearGradient(
            colors: [.white.opacity(start), .white.opacity(end)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
