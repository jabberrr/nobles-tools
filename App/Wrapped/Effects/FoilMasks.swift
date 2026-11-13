import SwiftUI

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

extension View {
    /// This view with the opaque parts of `hole` cut out of it.
    func foilCutout<Hole: View>(@ViewBuilder _ hole: () -> Hole) -> some View {
        let hole = hole()
        return overlay { hole.blendMode(.destinationOut) }
            .compositingGroup()
    }
}
