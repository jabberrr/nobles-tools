import SwiftUI
import Testing
import UIKit
@testable import NoblesTools

/// Renders the widget gallery to PNGs, one per widget and size, and Cafe Wrapped's pages, for
/// checking layouts by eye and for the README. Runs only when `SNAPSHOT_OUTPUT_DIR` is set (the
/// "Render widget previews" workflow sets it), so a local test run never writes into the repository.
@MainActor
struct WidgetSnapshotTests {
    @Test func rendersTheWidgetGallery() throws {
        try render(WidgetGallery.entries, scale: 2)
    }

    /// Wrapped's pages are phone-sized, so they render at 1× to keep the repository small.
    @Test func rendersCafeWrapped() throws {
        try render(WrappedGallery.entries, scale: 1)
    }

    private func render(_ entries: [WidgetGallery.Entry], scale: CGFloat) throws {
        guard let path = ProcessInfo.processInfo.environment["SNAPSHOT_OUTPUT_DIR"] else { return }
        let directory = URL(filePath: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for entry in entries {
            let renderer = ImageRenderer(content: entry.view)
            renderer.scale = scale
            renderer.isOpaque = true
            let png = try #require(renderer.uiImage?.pngData(), "Couldn't render \(entry.name)")
            try png.write(to: directory.appending(path: "\(entry.name).png"))
        }
    }
}
