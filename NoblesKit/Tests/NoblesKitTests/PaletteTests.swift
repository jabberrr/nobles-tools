import Foundation
import Testing
@testable import NoblesKit

struct PaletteTests {
    /// WCAG contrast: 4.5:1 for text, 3:1 for the accent, which marks icons and headings.
    @Test(arguments: Palette.allCases)
    func colorsStayLegibleOnBothEndsOfTheBackground(palette: Palette) {
        guard let colors = palette.colors else { return }
        for background in [colors.background, colors.backgroundEnd] {
            #expect(contrast(colors.primary, background) >= 4.5)
            #expect(contrast(colors.secondary, background) >= 4.5)
            #expect(contrast(colors.accent, background) >= 3)
        }
    }

    private func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Relative luminance of a 0xRRGGBB color.
    private func luminance(_ hex: UInt32) -> Double {
        let channels = [16, 8, 0].map { Double((hex >> UInt32($0)) & 0xFF) / 255 }
        let linear = channels.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
