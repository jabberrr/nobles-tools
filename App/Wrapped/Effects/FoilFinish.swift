import SwiftUI

/// A face of the foil filling the stage, to be cut to shape with `FoilMasks`: the outside, shiny
/// and puffed up around the item, or the duller inside, for foil that has been opened out.
struct FoilFinish: View {
    enum Face {
        case outside, inside
    }

    let face: Face
    let geometry: FoilGeometry

    var body: some View {
        let item = geometry.itemFrame
        FoilTextureFill(minimumSide: max(geometry.size.width, geometry.size.height), isTurned: face == .inside)
            .overlay {
                switch face {
                case .outside:
                    // Puffed up around the item: brightest just above its middle, darker out to
                    // its edges.
                    RadialGradient(
                        stops: [
                            .init(color: .white.opacity(0.18), location: 0),
                            .init(color: .white.opacity(0), location: 0.5),
                            .init(color: .black.opacity(0.3), location: 1),
                        ],
                        center: UnitPoint(
                            x: (item.midX - item.width * 0.06) / max(geometry.size.width, 1),
                            y: (item.midY - item.height * 0.1) / max(geometry.size.height, 1)
                        ),
                        startRadius: 0,
                        endRadius: min(item.width, item.height) * 0.42
                    )
                case .inside:
                    Color.black.opacity(0.16)
                }
            }
    }
}

/// Where flaps overlap, on a flap's outside, filling the stage. The top flap's lower edge rolls
/// over the sides with a bright lip, and the left side's edge lies over the right; each casts a
/// soft shadow on the flap beneath.
struct FoilFolds: View {
    let region: FoilRegion
    let geometry: FoilGeometry

    var body: some View {
        let unit = geometry.unit
        let size = geometry.size
        let foldY = geometry.foldY
        let seam = geometry.seamX
        let below = size.height - foldY
        ZStack {
            switch region {
            case .top:
                band(CGRect(x: 0, y: foldY - 10 * unit, width: size.width, height: 8 * unit), from: 0, to: 0.25, isVertical: true)
                lip(CGRect(x: 0, y: foldY - 2.2 * unit, width: size.width, height: 1.3 * unit))
            case .left:
                band(CGRect(x: 0, y: foldY, width: size.width, height: 8 * unit), from: 0.32, to: 0, isVertical: true)
                band(CGRect(x: seam - 10 * unit, y: foldY, width: 8 * unit, height: below), from: 0, to: 0.22, isVertical: false)
                lip(CGRect(x: seam - 2.2 * unit, y: foldY, width: 1.3 * unit, height: below))
            case .right:
                band(CGRect(x: 0, y: foldY, width: size.width, height: 8 * unit), from: 0.32, to: 0, isVertical: true)
                band(CGRect(x: seam, y: foldY, width: 8 * unit, height: below), from: 0.3, to: 0, isVertical: false)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Shade across `rect`, from `start` to `end` opacity of black, down or rightward.
    private func band(_ rect: CGRect, from start: Double, to end: Double, isVertical: Bool) -> some View {
        LinearGradient(
            colors: [.black.opacity(start), .black.opacity(end)],
            startPoint: isVertical ? .top : .leading,
            endPoint: isVertical ? .bottom : .trailing
        )
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    /// A fold's highlight.
    private func lip(_ rect: CGRect) -> some View {
        Color.white.opacity(0.7)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
