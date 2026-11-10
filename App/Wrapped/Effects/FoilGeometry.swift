import SwiftUI

/// The foil's three flaps. The top is folded down over the two sides, and the left side overlaps
/// the right at the seam between them.
enum FoilRegion: CaseIterable, Sendable {
    case top, left, right

    /// Bottom to top, so each flap lies over the ones it overlaps.
    static let drawingOrder: [FoilRegion] = [.right, .left, .top]
}

/// Where things are on the foil's stage: the wrapped content's frame with `margin` all around,
/// so foil around an item that reaches the content's edges isn't cut off.
struct FoilGeometry: Sendable {
    /// Room around the content for the foil to spread into, in points.
    static let margin: CGFloat = 28

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

    /// Scales the foil's thicknesses to the picture: 1 for a 220-point picture.
    var unit: CGFloat {
        min(max(min(itemFrame.width, itemFrame.height) / 220, 0.5), 1.4)
    }

    /// The fold between the top flap and the two sides below it.
    var foldY: CGFloat {
        itemFrame.minY + itemFrame.height * 0.42
    }

    /// The seam between the two sides.
    var seamX: CGFloat {
        itemFrame.midX
    }

    /// How big the foil is once it's crumpled into a ball.
    var ballDiameter: CGFloat {
        min(itemFrame.width, itemFrame.height) * 0.28
    }

    /// The part of the stage a flap covers. Neighbors overlap by a hair, so no hairline of
    /// whatever is beneath shows between them.
    func rect(of region: FoilRegion) -> CGRect {
        let overlap: CGFloat = 0.5
        let lowerHeight = size.height - foldY + overlap
        return switch region {
        case .top: CGRect(x: 0, y: 0, width: size.width, height: foldY + overlap)
        case .left: CGRect(x: 0, y: foldY - overlap, width: seamX + overlap, height: lowerHeight)
        case .right: CGRect(x: seamX - overlap, y: foldY - overlap, width: size.width - seamX + overlap, height: lowerHeight)
        }
    }

    /// Where a flap starts to peel back: its free edge, at the seam.
    func peelAnchor(of region: FoilRegion) -> UnitPoint {
        guard size.width > 0, size.height > 0 else { return .center }
        let y = switch region {
        case .top: foldY
        case .left, .right: foldY + (itemFrame.maxY - foldY) * 0.35
        }
        return UnitPoint(x: seamX / size.width, y: y / size.height)
    }
}
