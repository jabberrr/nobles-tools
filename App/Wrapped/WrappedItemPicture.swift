import SwiftUI
import NoblesKit

/// An item's picture: its product photo if it's a branded item, else its emoji, on a warm, softly
/// lit plate.
struct WrappedItemPicture: View {
    private let art: WrappedItemArt
    private let size: CGFloat

    init(item: CafeWrapped.Item, size: CGFloat = 220) {
        self.init(art: WrappedItemArt(item: item, size: size * 0.5), size: size)
    }

    /// The picture of an item bought as `name`, e.g. a charge's detail.
    init(itemNamed name: String, size: CGFloat = 220) {
        self.init(art: WrappedItemArt(itemNamed: name, size: size * 0.5), size: size)
    }

    private init(art: WrappedItemArt, size: CGFloat) {
        self.art = art
        self.size = size
    }

    var body: some View {
        art
            .frame(width: size, height: size)
            .background { plate }
            .accessibilityHidden(true)
    }

    /// The item's shape without the plate, laid out exactly like the picture: what `FoilWrap`
    /// shapes its foil to.
    var silhouette: some View {
        art.silhouette
            .frame(width: size, height: size)
    }

    private var plate: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: 0xFFF9EF), Color(hex: 0xFFE3BA), Color(hex: 0xF2AE63)],
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 0,
                    endRadius: size * 0.72
                )
            )
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: max(1, size * 0.012))
            }
            .shadow(color: .black.opacity(0.3), radius: size * 0.08, y: size * 0.04)
    }
}

/// An item on its own, with no plate: its product photo fitted in a rounded square, or its emoji.
struct WrappedItemArt: View {
    private let emoji: String
    private let productImage: String?
    /// The emoji's size in points. A photo fits a square a quarter bigger.
    private let size: CGFloat
    private var isSilhouette = false

    init(item: CafeWrapped.Item, size: CGFloat) {
        emoji = item.emoji
        productImage = item.productImage
        self.size = size
    }

    /// The art for an item bought as `name`, picked as `CafeWrapped.Item` picks it.
    init(itemNamed name: String, size: CGFloat) {
        emoji = CafeItemArt.emoji(for: name)
        productImage = CafeItemArt.productImage(for: name)
        self.size = size
    }

    /// The same art as a shape: opaque exactly where the item is drawn.
    var silhouette: WrappedItemArt {
        var silhouette = self
        silhouette.isSilhouette = true
        return silhouette
    }

    var body: some View {
        if let productImage {
            photo(productImage)
        } else {
            // An emoji is already opaque only where it's drawn, so it's its own silhouette.
            Text(emoji)
                .font(WrappedStyle.emoji(size))
        }
    }

    private func photo(_ name: String) -> some View {
        let side = size * 1.25
        let shape = RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
        let image = Image(name).resizable().scaledToFit()
        return Group {
            if isSilhouette {
                // Laid out as the photo, so the shape lands exactly where the photo would.
                image
                    .hidden()
                    .overlay { shape.fill(Color.black) }
            } else {
                image.clipShape(shape)
            }
        }
        .frame(width: side, height: side)
    }
}
