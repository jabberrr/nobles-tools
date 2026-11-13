import CoreGraphics

/// Where things are on the foil's stage: the wrapped content's frame with `margin` all around, so
/// foil that puffs out past the content's edges isn't cut off.
struct FoilGeometry: Sendable {
    /// Room around the content for the foil to spread into, in points.
    static let margin: CGFloat = 24

    /// The stage: the content's frame plus `margin` on every side.
    let size: CGSize

    /// The content's frame, where the item's silhouette is laid out.
    var itemFrame: CGRect {
        CGRect(
            x: Self.margin,
            y: Self.margin,
            width: max(size.width - 2 * Self.margin, 0),
            height: max(size.height - 2 * Self.margin, 0)
        )
    }

    /// The middle of the content, where the bundle sits.
    var center: CGPoint {
        CGPoint(x: itemFrame.midX, y: itemFrame.midY)
    }

    /// Half the content's shorter side: the bundle and its hole are sized from it.
    var radius: CGFloat {
        min(itemFrame.width, itemFrame.height) / 2
    }

    /// Scales the foil's line widths, blurs and shadows to the picture: 1 for a 220-point picture.
    var unit: CGFloat {
        min(max(radius / 110, 0.5), 1.4)
    }

    /// How big the foil is once it's crumpled into a ball.
    var ballDiameter: CGFloat {
        radius * 0.56
    }

    /// The point `offset` radii from the middle: x across, y down.
    func point(_ offset: CGVector) -> CGPoint {
        CGPoint(x: center.x + offset.dx * radius, y: center.y + offset.dy * radius)
    }
}
