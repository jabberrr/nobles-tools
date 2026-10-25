import SwiftUI
import NoblesKit

/// Palette, font and background: the part of the editor every kind shares.
struct AppearanceSection: View {
    @Binding var theme: Theme

    var body: some View {
        Section("Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Colors", value: theme.palette.displayName)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                    ForEach(Palette.allCases) { palette in
                        Button {
                            theme.palette = palette
                        } label: {
                            PaletteSwatch(palette: palette, isSelected: theme.palette == palette)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(palette.displayName)
                        .accessibilityAddTraits(theme.palette == palette ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)

            Picker("Font", selection: $theme.font) {
                ForEach(FontStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            Picker("Background", selection: $theme.background) {
                ForEach(NoblesKit.BackgroundStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// A palette as a round swatch: its background with an accent dot. Classic, which follows the
/// system appearance, is split light and dark.
private struct PaletteSwatch: View {
    let palette: Palette
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let colors = palette.colors {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: colors.background), Color(hex: colors.backgroundEnd)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Circle()
                    .fill(Color(hex: colors.accent))
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.5),
                            .init(color: Color(hex: 0x1C1C1E), location: 0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 12, height: 12)
            }
            Circle()
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .frame(width: 40, height: 40)
        .padding(4)
        .overlay {
            if isSelected {
                Circle().strokeBorder(Color.accentColor, lineWidth: 2.5)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Circle())
    }
}
