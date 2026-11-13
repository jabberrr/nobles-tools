import SwiftUI
import NoblesKit

/// The persona card's shape, shared by both its faces and by the page that turns it over.
enum PersonaCard {
    static let size = CGSize(width: 290, height: 370)
    static let cornerRadius: CGFloat = 32
}

/// The side you see first: foil with a "?" stamped into it, which the shimmer sweeps over. Its
/// shimmer stops once it has turned away.
struct PersonaCardBack: View {
    let isShimmering: Bool

    var body: some View {
        FoilSurface(cornerRadius: PersonaCard.cornerRadius, isShimmering: isShimmering) {
            // A light wash calms the crinkles around the "?", so it reads at a glance.
            Color.white.opacity(0.22)
            FoilStamp("?", size: 220)
        }
    }
}

/// The revealed side: the persona's emoji, title and tagline on a dark card in a frame of foil,
/// each coming in once the card has turned.
struct PersonaCardFront: View {
    let persona: CafePersona
    let isRevealed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PersonaCard.cornerRadius, style: .continuous)
        VStack(spacing: 16) {
            Text(persona.emoji)
                .font(WrappedStyle.emoji(96))
                .wrappedReveal(isRevealed, delay: 0.1, style: .pop)
            Text(persona.title)
                .font(WrappedStyle.title(28))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .wrappedReveal(isRevealed, delay: 0.3)
            Text(persona.tagline)
                .font(WrappedStyle.body)
                .foregroundStyle(WrappedStyle.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .wrappedReveal(isRevealed, delay: 0.45)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque, so the light behind the card never shows through the text.
        .background {
            shape
                .fill(WrappedStyle.ink)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
        }
        .overlay {
            FoilSurface(cornerRadius: PersonaCard.cornerRadius)
                .mask { shape.strokeBorder(lineWidth: 6) }
        }
    }
}

#Preview("Persona card") {
    HStack(spacing: 24) {
        PersonaCardBack(isShimmering: true)
        PersonaCardFront(persona: .regular, isRevealed: true)
    }
    .frame(width: PersonaCard.size.width * 2 + 24, height: PersonaCard.size.height)
    .foregroundStyle(.white)
    .padding(40)
    .background(Color(hex: 0x9D174D))
}
