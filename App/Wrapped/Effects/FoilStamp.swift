import SwiftUI

/// A glyph stamped into foil, such as the "?" on the persona card: the foil itself pressed in,
/// darker than the foil around it. Lit from the upper left like the foil, the walls it was pressed
/// past shade its upper left edges and catch the light along its lower right. It lies across two
/// creases, each facet at a slightly different angle, as if pressed into crumpled foil.
///
/// Fills its frame, with the glyph in the middle. Give it the foil's own frame (as a
/// `FoilSurface` stamp has), so the pressed foil lines up with the foil around it.
struct FoilStamp: View {
    private let glyph: String
    private let size: CGFloat

    /// - Parameter size: The glyph's point size.
    init(_ glyph: String, size: CGFloat) {
        self.glyph = glyph
        self.size = size
    }

    var body: some View {
        ZStack {
            Color.white.opacity(0.85)
                .mask { glyphShape }
                .offset(x: depth, y: depth * 1.25)
                .blur(radius: 0.4)
            WrappedStyle.ink.opacity(0.7)
                .mask { glyphShape }
                .offset(x: -depth, y: -depth * 1.25)
                .blur(radius: 0.6)
            FoilTextureFill()
                .overlay { Color.black.opacity(0.4) }
                .overlay { facetShading }
                .overlay { innerShadow }
                .mask { glyphShape }
        }
        .accessibilityHidden(true)
    }

    /// How far the walls show past the glyph's edges.
    private var depth: CGFloat { size / 100 }

    /// The glyph's shape, each facet turned its own way.
    private var glyphShape: some View {
        ZStack {
            ForEach(StampFacet.all.indices, id: \.self) { index in
                let facet = StampFacet.all[index]
                Text(glyph)
                    .font(WrappedStyle.number(size))
                    .foregroundStyle(.black)
                    .rotationEffect(.degrees(facet.degrees))
                    .offset(facet.offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask { facet.band }
            }
        }
    }

    /// Each facet catching the light a little differently.
    private var facetShading: some View {
        ZStack {
            ForEach(StampFacet.all.indices, id: \.self) { index in
                let facet = StampFacet.all[index]
                facet.band.fill(facet.shading)
            }
        }
    }

    /// The shade along the inside of the upper left edges, cast by the walls above them.
    private var innerShadow: some View {
        Color.black.opacity(0.5)
            .mask {
                glyphShape
                    .overlay {
                        glyphShape
                            .offset(x: depth * 1.5, y: depth * 2)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .blur(radius: 1.2)
    }
}

/// One facet of a stamp: the band of the frame between two creases, where the glyph is turned
/// `degrees` and nudged by `offset`, and the pressed foil is tinted with `shading`.
private struct StampFacet: Sendable {
    let band: CreaseBand
    let degrees: Double
    let offset: CGSize
    let shading: Color

    /// Two creases across the middle of the frame: one rising to the right, through the upper
    /// part of a glyph in the middle, and one falling to the right, through its lower part.
    private static let upperCrease = Crease(left: 0.47, right: 0.35)
    private static let lowerCrease = Crease(left: 0.53, right: 0.63)

    static let all = [
        StampFacet(band: CreaseBand(top: .frameTop, bottom: upperCrease), degrees: -5.5, offset: .zero, shading: .white.opacity(0.06)),
        StampFacet(band: CreaseBand(top: upperCrease, bottom: lowerCrease), degrees: -4.5, offset: CGSize(width: 0.8, height: 0), shading: .clear),
        StampFacet(band: CreaseBand(top: lowerCrease, bottom: .frameBottom), degrees: -3.5, offset: CGSize(width: 1.2, height: 0.4), shading: .black.opacity(0.08)),
    ]
}

/// A straight crease across a frame, from a point on its left edge to one on its right, each as
/// a share of the frame's height from the top.
private struct Crease: Sendable {
    let left: CGFloat
    let right: CGFloat

    static let frameTop = Crease(left: 0, right: 0)
    static let frameBottom = Crease(left: 1, right: 1)
}

/// The band of a frame between two creases, reaching half a point past each, so neighboring
/// bands overlap and no seam shows between them.
private struct CreaseBand: Shape {
    let top: Crease
    let bottom: Crease

    func path(in rect: CGRect) -> Path {
        let overlap: CGFloat = 0.5
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + top.left * rect.height - overlap))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + top.right * rect.height - overlap))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bottom.right * rect.height + overlap))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bottom.left * rect.height + overlap))
        path.closeSubpath()
        return path
    }
}

#Preview("Foil stamp") {
    FoilSurface(cornerRadius: 32) {
        Color.white.opacity(0.22)
        FoilStamp("?", size: 220)
    }
    .frame(width: 290, height: 370)
    .padding(40)
    .background(Color(hex: 0x9D174D))
}
