import SwiftUI

/// How far each part of the foil stands off the item, in points for a 220-point picture
/// (`FoilGeometry.unit` scales them).
enum FoilGrowth {
    /// The wrap.
    static let wrap: CGFloat = 10
    /// The dark gap under the wrap: a little inside it, so it only shows through the seams.
    static let gap: CGFloat = 9
    /// What a peeled flap uncovers: the item, a hair bigger.
    static let hole: CGFloat = 1.5
    /// The rolled edge of a peeled flap.
    static let curl: CGFloat = 7
    /// The opened-out foil left crumpled around the item.
    static let opened: CGFloat = 16

    /// How much the wrap's outline wanders, and its seed, shared by the wrap and its gap so they
    /// line up.
    static let wrapRumple = 0.12
    static let wrapSeed: UInt64 = 0xF011
}

/// Where to stamp the silhouette so the stamps together make it grown by some points: the
/// silhouette itself plus a ring of copies around it, or two rings when it grows far, so a thin
/// item stays solid. Jittering the radii rumples the outline like crushed foil.
struct FoilOutline: Sendable {
    let offsets: [CGSize]

    init(growth: CGFloat, rumple: Double = 0, seed: UInt64 = 0, copies: Int = 12) {
        var random = SeededRandom(seed: seed)
        var offsets = [CGSize.zero]
        let radii = growth > 12 ? [growth, growth / 2] : (growth > 0 ? [growth] : [])
        for radius in radii {
            for index in 0..<copies {
                let angle = (Double(index) + random.value(in: -0.25...0.25)) / Double(copies) * 2 * Double.pi
                let reach = Double(radius) * (1 + random.value(in: -rumple...(rumple / 2)))
                offsets.append(CGSize(width: cos(angle) * reach, height: sin(angle) * reach))
            }
        }
        self.offsets = offsets
    }
}

/// The item's silhouette grown by stamping it at every offset of `outline`: together the stamps
/// are opaque wherever the grown outline is. Fills the foil's stage, with the silhouette laid out
/// in the content's frame at its middle. For masks only, so the silhouette's colors never show.
struct GrownSilhouette<Silhouette: View>: View {
    let silhouette: Silhouette
    let geometry: FoilGeometry
    let outline: FoilOutline

    var body: some View {
        let item = geometry.itemFrame.size
        ZStack {
            ForEach(outline.offsets.indices, id: \.self) { index in
                silhouette
                    .frame(width: item.width, height: item.height)
                    .offset(outline.offsets[index])
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }
}

/// The masks the foil is cut with, made from the item's silhouette. Each fills the foil's stage.
@MainActor
struct FoilMasks<Silhouette: View> {
    let silhouette: Silhouette
    let geometry: FoilGeometry

    /// The silhouette grown by `growth` points. Small growths need fewer stamps.
    func grown(_ growth: CGFloat, rumple: Double = 0, seed: UInt64 = 0, copies: Int? = nil) -> GrownSilhouette<Silhouette> {
        let outline = FoilOutline(
            growth: growth * geometry.unit,
            rumple: rumple,
            seed: seed,
            copies: copies ?? (growth < 4 ? 6 : 12)
        )
        return GrownSilhouette(silhouette: silhouette, geometry: geometry, outline: outline)
    }

    /// The wrap's outline.
    func wrap(copies: Int? = nil) -> GrownSilhouette<Silhouette> {
        grown(FoilGrowth.wrap, rumple: FoilGrowth.wrapRumple, seed: FoilGrowth.wrapSeed, copies: copies)
    }

    /// A ring around the item, from its edge out to `growth`.
    func ring(_ growth: CGFloat, rumple: Double = 0, seed: UInt64 = 0) -> some View {
        grown(growth, rumple: rumple, seed: seed)
            .foilCutout { grown(FoilGrowth.hole) }
    }

    /// The part of the stage a flap covers.
    func region(_ region: FoilRegion) -> some View {
        let rect = geometry.rect(of: region)
        return Rectangle()
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

extension View {
    /// This view with the opaque parts of `hole` cut out of it.
    func foilCutout<Hole: View>(@ViewBuilder _ hole: () -> Hole) -> some View {
        let hole = hole()
        return overlay { hole.blendMode(.destinationOut) }
            .compositingGroup()
    }
}
