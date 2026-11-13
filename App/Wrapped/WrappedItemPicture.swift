import SwiftUI
import UIKit
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

    /// The rounded box the item fills in the middle of the picture: what `FoilWrap` covers.
    var itemBounds: FoilItemBounds {
        art.bounds
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
    /// The product photo's asset name and size, when the app has a photo of the item.
    private let photo: (name: String, size: CGSize)?
    /// The emoji's size in points. A photo fits a square a quarter bigger.
    private let size: CGFloat

    init(item: CafeWrapped.Item, size: CGFloat) {
        self.init(emoji: item.emoji, productImage: item.productImage, size: size)
    }

    /// The art for an item bought as `name`, picked as `CafeWrapped.Item` picks it.
    init(itemNamed name: String, size: CGFloat) {
        self.init(emoji: CafeItemArt.emoji(for: name), productImage: CafeItemArt.productImage(for: name), size: size)
    }

    /// Falls back to the emoji for a product the app has no photo of.
    private init(emoji: String, productImage: String?, size: CGFloat) {
        self.emoji = emoji
        photo = productImage.flatMap { name in UIImage(named: name).map { (name: name, size: $0.size) } }
        self.size = size
    }

    /// The rounded box the art fills, centered in its frame: the photo as fitted, or a square an
    /// emoji's drawing stays inside, its corners well rounded since emoji rarely fill them.
    var bounds: FoilItemBounds {
        guard let photo, photo.size.width > 0, photo.size.height > 0 else {
            let side = size * 1.15
            return FoilItemBounds(size: CGSize(width: side, height: side), cornerRadius: side * 0.35)
        }
        let scale = min(photoSide / photo.size.width, photoSide / photo.size.height)
        return FoilItemBounds(
            size: CGSize(width: photo.size.width * scale, height: photo.size.height * scale),
            cornerRadius: photoCornerRadius
        )
    }

    var body: some View {
        if let photo {
            Image(photo.name)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous))
                .frame(width: photoSide, height: photoSide)
        } else {
            Text(emoji)
                .font(WrappedStyle.emoji(size))
        }
    }

    /// The square a photo is fitted in.
    private var photoSide: CGFloat {
        size * 1.25
    }

    private var photoCornerRadius: CGFloat {
        photoSide * 0.12
    }
}
