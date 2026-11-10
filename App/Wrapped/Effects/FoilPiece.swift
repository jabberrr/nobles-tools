import SwiftUI

/// One piece of the foil, drawn into a canvas the size of the foil's whole frame
/// (`FoilGeometry`): the item's `silhouette` grown into an outline, maybe hollowed into a ring
/// and cut to one flap, then painted.
struct FoilPiece<Silhouette: View>: View {
    let spec: FoilPieceSpec
    let geometry: FoilGeometry
    let silhouette: Silhouette

    var body: some View {
        let painter = FoilPainter(spec: spec, geometry: geometry)
        let item = geometry.itemFrame.size
        let textureSide = max(geometry.size.width, geometry.size.height)
        Canvas { context, _ in
            painter.draw(in: &context)
        } symbols: {
            silhouette
                .frame(width: item.width, height: item.height)
                .tag(FoilPainter.itemSymbol)
            FoilArt.texture
                .frame(width: textureSide, height: textureSide)
                .tag(FoilPainter.textureSymbol)
        }
        .accessibilityHidden(true)
    }
}

/// What a `FoilPiece` draws. Sizes are in points for a 220-point picture (`FoilGeometry.unit`).
struct FoilPieceSpec: Sendable {
    enum Paint: Sendable {
        /// Plain white, for masks.
        case mask
        /// Flat and dark: what shows through the seams once the foil loosens.
        case gap
        /// The shiny outer face, puffed up, and creased where its flap overlaps or lies under
        /// another.
        case outside
        /// The duller inner face, for foil that has been opened out.
        case inside
        /// The rolled edge of foil peeling back: the inner face, bright along the fold.
        case curl
    }

    /// How far the outline stands off the item.
    var growth: CGFloat
    /// How much the outline wanders, as a share of `growth`: 0 is a smooth offset.
    var rumple: Double = 0
    /// Seeds the wandering, so pieces that should line up do.
    var seed: UInt64 = 0
    /// Hollows it into a ring by cutting out the item grown by this much.
    var hollow: CGFloat?
    /// The blur that rounds off the outline before it's cut crisp.
    var smoothing: CGFloat = 3
    var region: FoilRegion?
    var paint: Paint
}

extension FoilPieceSpec {
    /// A flap of the wrap, shiny side out.
    static func wrapped(_ region: FoilRegion) -> FoilPieceSpec {
        FoilPieceSpec(growth: 10, rumple: 0.15, seed: 0xF011, region: region, paint: .outside)
    }

    /// The dark gap under a flap, a little inside it so it only shows through the seams.
    static func gap(_ region: FoilRegion) -> FoilPieceSpec {
        FoilPieceSpec(growth: 9, rumple: 0.15, seed: 0xF011, region: region, paint: .gap)
    }

    /// The item's own outline, a hair bigger: what a fully peeled flap uncovers.
    static let hole = FoilPieceSpec(growth: 1.5, smoothing: 2, paint: .mask)

    /// The rolled edge of a peeled flap, hugging the hole.
    static func curl(_ region: FoilRegion) -> FoilPieceSpec {
        FoilPieceSpec(growth: 7.5, hollow: 1.5, smoothing: 1.8, region: region, paint: .curl)
    }

    /// A flap opened out around the item, crumpled.
    static func opened(_ region: FoilRegion) -> FoilPieceSpec {
        FoilPieceSpec(growth: 22, rumple: 0.35, seed: 0x0FE2, hollow: 1.5, smoothing: 3.5, region: region, paint: .inside)
    }
}

/// Where to stamp the silhouette so the stamps together make it grown by some points: the
/// silhouette itself plus rings of copies around it. Jittering the rings' radii rumples the
/// outline like crushed foil.
struct FoilOutline: Sendable {
    private let offsets: [CGPoint]

    init(growth: CGFloat, rumple: Double = 0, seed: UInt64 = 0, copies: Int = 12) {
        var random = SeededRandom(seed: seed)
        var offsets = [CGPoint.zero]
        // A second, inner ring keeps a thin item solid when the outer ring stands far off it.
        let radii = growth > 12 ? [growth, growth / 2] : (growth > 0 ? [growth] : [])
        for radius in radii {
            for index in 0..<copies {
                let angle = (Double(index) + random.value(in: -0.25...0.25)) / Double(copies) * 2 * Double.pi
                let reach = Double(radius) * (1 + random.value(in: -rumple...(rumple / 2)))
                offsets.append(CGPoint(x: cos(angle) * reach, y: sin(angle) * reach))
            }
        }
        self.offsets = offsets
    }

    /// Draws `item` at every stamp around `center`.
    func stamp(_ item: GraphicsContext.ResolvedSymbol, in context: inout GraphicsContext, around center: CGPoint) {
        for offset in offsets {
            context.draw(item, at: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
        }
    }
}

/// Draws a `FoilPieceSpec` into a canvas the size of `geometry`.
///
/// The outline is the stamped silhouette blurred and cut at half opacity (the "metaball" trick),
/// so it comes out smooth and crisp whatever the item's shape. The foil photo goes inside it,
/// then light and shade go on top, kept to the foil.
struct FoilPainter: Sendable {
    /// The canvas symbols: the item's silhouette, and the foil photo covering the canvas.
    static let itemSymbol = 0
    static let textureSymbol = 1
    /// How much of the photo's color is kept, so the foil reads as silver.
    static let saturation = 0.25
    /// The foil's color under the photo.
    static let silver = Color(white: 0.78)

    let spec: FoilPieceSpec
    let geometry: FoilGeometry

    private var bounds: CGRect {
        CGRect(origin: .zero, size: geometry.size)
    }

    private var center: CGPoint {
        CGPoint(x: geometry.itemFrame.midX, y: geometry.itemFrame.midY)
    }

    private var unit: CGFloat {
        geometry.unit
    }

    func draw(in context: inout GraphicsContext) {
        guard let item = context.resolveSymbol(id: Self.itemSymbol) else { return }
        let texture = context.resolveSymbol(id: Self.textureSymbol)
        if let region = spec.region {
            context.clip(to: Path(geometry.rect(of: region)))
        }
        context.drawLayer { layer in
            drawOutline(item, in: &layer)
            paint(&layer, item: item, texture: texture)
        }
    }

    /// The outline, in white.
    private func drawOutline(_ item: GraphicsContext.ResolvedSymbol, in layer: inout GraphicsContext) {
        let outer = FoilOutline(growth: spec.growth * unit, rumple: spec.rumple, seed: spec.seed)
        var shape = layer
        // Filters apply last-added first: round off the stamps, cut a crisp edge, soften it a hair.
        shape.addFilter(.blur(radius: 0.6))
        shape.addFilter(.alphaThreshold(min: 0.5, color: .white))
        shape.addFilter(.blur(radius: spec.smoothing * unit))
        shape.drawLayer { stamps in
            outer.stamp(item, in: &stamps, around: center)
            if let hollow = spec.hollow {
                stamps.blendMode = .destinationOut
                FoilOutline(growth: hollow * unit).stamp(item, in: &stamps, around: center)
            }
        }
    }

    private func paint(
        _ layer: inout GraphicsContext,
        item: GraphicsContext.ResolvedSymbol,
        texture: GraphicsContext.ResolvedSymbol?
    ) {
        switch spec.paint {
        case .mask:
            break
        case .gap:
            var dark = layer
            dark.blendMode = .sourceIn
            dark.fill(Path(bounds), with: .color(Color(white: 0.06, opacity: 0.9)))
        case .outside:
            drawTexture(texture, in: &layer, isTurned: false)
            light(&layer, strength: 1)
            emboss(&layer, item: item, strength: 1)
            if let region = spec.region {
                crease(&layer, region: region)
            }
        case .inside:
            drawTexture(texture, in: &layer, isTurned: true)
            wash(&layer, with: .black.opacity(0.16))
            light(&layer, strength: 0.7)
            emboss(&layer, item: item, strength: 0.8)
        case .curl:
            drawTexture(texture, in: &layer, isTurned: true)
            wash(&layer, with: .black.opacity(0.3))
            fold(&layer, item: item)
        }
    }

    /// The foil photo, inside the outline, over plain silver. The inner face turns and mirrors
    /// it, so it doesn't repeat the outer face.
    private func drawTexture(_ texture: GraphicsContext.ResolvedSymbol?, in layer: inout GraphicsContext, isTurned: Bool) {
        var photo = layer
        photo.blendMode = .sourceIn
        photo.fill(Path(bounds), with: .color(Self.silver))
        guard let texture else { return }
        photo.blendMode = .sourceAtop
        photo.addFilter(.saturation(Self.saturation))
        if isTurned {
            photo.translateBy(x: center.x, y: center.y)
            photo.rotate(by: .degrees(90))
            photo.scaleBy(x: -1, y: 1)
            photo.translateBy(x: -center.x, y: -center.y)
        }
        photo.draw(texture, at: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    /// `color` over all of the foil.
    private func wash(_ layer: inout GraphicsContext, with color: Color) {
        var wash = layer
        wash.blendMode = .sourceAtop
        wash.fill(Path(bounds), with: .color(color))
    }

    /// Light from the upper left across the item, shade toward the lower right.
    private func light(_ layer: inout GraphicsContext, strength: Double) {
        let frame = geometry.itemFrame
        var light = layer
        light.blendMode = .sourceAtop
        light.fill(
            Path(bounds),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.3 * strength), location: 0),
                    .init(color: .white.opacity(0), location: 0.45),
                    .init(color: .black.opacity(0.22 * strength), location: 1),
                ]),
                startPoint: CGPoint(x: frame.minX + frame.width * 0.15, y: frame.minY + frame.height * 0.1),
                endPoint: CGPoint(x: frame.maxX - frame.width * 0.15, y: frame.maxY - frame.height * 0.1)
            )
        )
    }

    /// Makes the foil look puffed up around the item: dark along its lower-right edges, bright
    /// along its upper-left ones.
    private func emboss(_ layer: inout GraphicsContext, item: GraphicsContext.ResolvedSymbol, strength: Double) {
        let rim = FoilOutline(growth: spec.growth * unit, rumple: spec.rumple, seed: spec.seed, copies: 6)
        edgeWash(&layer, rim: rim, item: item, color: .black.opacity(0.5 * strength), shift: CGSize(width: -2.5 * unit, height: -3.5 * unit), blur: 6 * unit)
        edgeWash(&layer, rim: rim, item: item, color: .white.opacity(0.65 * strength), shift: CGSize(width: 1.5 * unit, height: 2 * unit), blur: 2.5 * unit)
    }

    /// `color` over the foil wherever it lies outside `rim` moved by `shift`, blurred: a band
    /// along the edges that face away from the shift.
    private func edgeWash(
        _ layer: inout GraphicsContext,
        rim: FoilOutline,
        item: GraphicsContext.ResolvedSymbol,
        color: Color,
        shift: CGSize,
        blur: CGFloat
    ) {
        var wash = layer
        wash.blendMode = .sourceAtop
        wash.addFilter(.blur(radius: blur))
        wash.drawLayer { band in
            band.fill(Path(bounds.insetBy(dx: -40, dy: -40)), with: .color(color))
            band.blendMode = .destinationOut
            rim.stamp(item, in: &band, around: CGPoint(x: center.x + shift.width, y: center.y + shift.height))
        }
    }

    /// The curl's fold: brightest along its outer edge, where the foil turns over.
    private func fold(_ layer: inout GraphicsContext, item: GraphicsContext.ResolvedSymbol) {
        let inner = FoilOutline(growth: (spec.growth - 2.5) * unit, copies: 8)
        var highlight = layer
        highlight.blendMode = .sourceAtop
        highlight.addFilter(.blur(radius: 1.2 * unit))
        highlight.drawLayer { band in
            band.fill(Path(bounds.insetBy(dx: -20, dy: -20)), with: .color(.white.opacity(0.8)))
            band.blendMode = .destinationOut
            inner.stamp(item, in: &band, around: center)
        }
    }

    /// Where flaps overlap. The top flap's lower edge rolls over the sides with a bright lip, and
    /// the left side's edge lies over the right; each casts a soft shadow on the flap beneath.
    private func crease(_ layer: inout GraphicsContext, region: FoilRegion) {
        let foldY = geometry.foldY
        let seam = geometry.seamX
        var crease = layer
        crease.blendMode = .sourceAtop
        switch region {
        case .top:
            band(&crease, CGRect(x: 0, y: foldY - 10 * unit, width: bounds.width, height: 8 * unit), from: 0, to: 0.25, vertical: true)
            lip(&crease, CGRect(x: 0, y: foldY - 2.2 * unit, width: bounds.width, height: 1.3 * unit))
        case .left:
            band(&crease, CGRect(x: 0, y: foldY, width: bounds.width, height: 8 * unit), from: 0.32, to: 0, vertical: true)
            band(&crease, CGRect(x: seam - 10 * unit, y: foldY, width: 8 * unit, height: bounds.height), from: 0, to: 0.22, vertical: false)
            lip(&crease, CGRect(x: seam - 2.2 * unit, y: foldY, width: 1.3 * unit, height: bounds.height))
        case .right:
            band(&crease, CGRect(x: 0, y: foldY, width: bounds.width, height: 8 * unit), from: 0.32, to: 0, vertical: true)
            band(&crease, CGRect(x: seam, y: foldY, width: 8 * unit, height: bounds.height), from: 0.3, to: 0, vertical: false)
        }
    }

    /// Shade across `rect`, from `start` to `end` opacity of black, down or rightward.
    private func band(_ context: inout GraphicsContext, _ rect: CGRect, from start: Double, to end: Double, vertical: Bool) {
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [.black.opacity(start), .black.opacity(end)]),
                startPoint: rect.origin,
                endPoint: vertical ? CGPoint(x: rect.minX, y: rect.maxY) : CGPoint(x: rect.maxX, y: rect.minY)
            )
        )
    }

    /// A fold's highlight.
    private func lip(_ context: inout GraphicsContext, _ rect: CGRect) {
        context.fill(Path(rect), with: .color(.white.opacity(0.7)))
    }
}
