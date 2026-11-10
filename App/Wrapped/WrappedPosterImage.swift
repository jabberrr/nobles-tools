import SwiftUI
import UIKit
import CoreTransferable
import UniformTypeIdentifiers
import NoblesKit

/// The summary poster as a PNG to share, drawn only when the share sheet asks for it.
struct WrappedPosterImage: Transferable, Sendable {
    let wrapped: CafeWrapped

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            try await image.pngData()
        }
    }

    /// The poster at 3×: 1080 × 1920 pixels.
    @MainActor
    private func pngData() throws -> Data {
        let poster = WrappedPoster(wrapped: wrapped, cornerRadius: 0)
            .environment(\.wrappedIsStatic, true)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
