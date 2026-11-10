import SwiftUI
import NoblesKit

/// The finale: the poster of the semester's headline stats, to share as an image, and Done.
struct SummaryPage: View {
    let wrapped: CafeWrapped
    let isActive: Bool
    let onDone: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                WrappedEyebrow("That's a wrap", symbol: "gift.fill")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                GeometryReader { proxy in
                    let size = WrappedPoster.size
                    WrappedPoster(wrapped: wrapped)
                        .scaleEffect(min(1, proxy.size.width / size.width, proxy.size.height / size.height))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                .wrappedReveal(isActive, delay: 0.3, style: .pop)
                buttons
                    .wrappedReveal(isActive, delay: 0.9)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.top, 16)
            .padding(.bottom, 20)
            ConfettiBurst(trigger: isActive ? 1 : 0)
        }
    }

    private var buttons: some View {
        let image = WrappedPosterImage(wrapped: wrapped)
        return HStack(spacing: 12) {
            ShareLink(item: image, preview: SharePreview("My \(wrapped.period.name) Cafe Wrapped", image: image)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(WrappedButtonStyle())
            Button("Done", action: onDone)
                .buttonStyle(WrappedButtonStyle(isProminent: false))
        }
    }
}

#Preview {
    SummaryPage(wrapped: .sample, isActive: true) {}
        .foregroundStyle(.white)
        .background(Color(hex: 0x14112B))
}
