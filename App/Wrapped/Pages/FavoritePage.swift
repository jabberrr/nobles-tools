import SwiftUI
import UIKit
import NoblesKit

/// The reveal of #1: its picture in foil shaped like it, which comes off in stages, one per tap,
/// then confetti, its name and its numbers. Taps on the foil open it; taps anywhere else still
/// turn the page. VoiceOver finds the foil as a button and, once it's off, the item in one
/// sentence.
struct FavoritePage: View {
    /// Taps it takes to get the foil off: one per stage.
    static let tapsToUnwrap = 5

    let item: CafeWrapped.Item
    let isActive: Bool
    @Binding var isUnwrapped: Bool
    private let initialTaps: Int

    /// Taps made on the foil so far, for the dots that count down.
    @State private var taps: Int
    /// Whether this visit began wrapped. The foil then stays in place once it's off, so its last
    /// stage plays out; a visit that begins unwrapped shows the plain picture.
    @State private var beganWrapped: Bool
    @State private var confetti = 0

    init(item: CafeWrapped.Item, isActive: Bool, initialTaps: Int, isUnwrapped: Binding<Bool>) {
        self.item = item
        self.isActive = isActive
        self.initialTaps = initialTaps
        _isUnwrapped = isUnwrapped
        _taps = State(initialValue: initialTaps)
        _beganWrapped = State(initialValue: !isUnwrapped.wrappedValue)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                WrappedEyebrow("Your #1", symbol: "crown.fill")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Spacer(minLength: 0)
                picture
                    .wrappedReveal(isActive, delay: 0.3, style: .pop)
                // Both stay laid out, so the picture doesn't move when one gives way to the other.
                ZStack(alignment: .top) {
                    hint
                        .opacity(isUnwrapped ? 0 : 1)
                        // The foil tells VoiceOver itself how many taps are left.
                        .accessibilityHidden(true)
                    details
                        .opacity(isUnwrapped ? 1 : 0)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(detailsDescription)
                        .accessibilityHidden(!isUnwrapped)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, WrappedStyle.margin)
            .padding(.top, 20)
            .padding(.bottom, 24)
            ConfettiBurst(trigger: confetti, emojis: [item.emoji])
        }
    }

    @ViewBuilder
    private var picture: some View {
        if beganWrapped {
            FoilWrap(
                tapsToUnwrap: Self.tapsToUnwrap,
                initialTaps: initialTaps,
                onTap: { taps = $0 },
                onUnwrap: { unwrap() }
            ) {
                WrappedItemPicture(item: item)
            } silhouette: {
                WrappedItemPicture(item: item).silhouette
            }
        } else {
            WrappedItemPicture(item: item)
        }
    }

    private var hint: some View {
        VStack(spacing: 14) {
            Text("Tap the foil to take it off")
                .font(WrappedStyle.lead)
            HStack(spacing: 8) {
                ForEach(0..<Self.tapsToUnwrap, id: \.self) { dot in
                    Circle()
                        .fill(dot < tapsLeft ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 10, height: 10)
                }
            }
            .animation(.spring(duration: 0.3), value: taps)
        }
        .wrappedReveal(isActive, delay: 0.8, style: .fade)
    }

    private var tapsLeft: Int {
        max(0, Self.tapsToUnwrap - taps)
    }

    /// Hidden until the foil is off; then each part pops or rises in turn.
    private var details: some View {
        let isRevealed = isActive && isUnwrapped
        return VStack(spacing: 14) {
            Text(item.name)
                .font(WrappedStyle.hero(28))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isRevealed, delay: 0.35, style: .pop)
            HStack(spacing: 12) {
                WrappedStatTile(caption: item.count == 1 ? "time" : "times") {
                    CountingText(Double(item.count), isActive: isRevealed, duration: 1, delay: 0.8, format: WrappedFormat.whole)
                }
                .wrappedReveal(isRevealed, delay: 0.7)
                WrappedStatTile(caption: "in all") {
                    CountingText(WrappedFormat.double(item.total), isActive: isRevealed, duration: 1.2, delay: 1, format: WrappedFormat.dollars)
                }
                .wrappedReveal(isRevealed, delay: 0.9)
            }
            VStack(spacing: 2) {
                Text("First bought on \(WrappedFormat.day(LocalDate(item.firstBought)))")
                Text("Mostly from \(item.cafeName)")
            }
            .font(WrappedStyle.caption)
            .foregroundStyle(WrappedStyle.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .wrappedReveal(isRevealed, delay: 1.3)
        }
    }

    /// What VoiceOver reads for the details.
    private var detailsDescription: String {
        let first = WrappedFormat.day(LocalDate(item.firstBought))
        return "\(item.name). You got it \(WrappedFormat.count(item.count, "time")), \(item.total.usd()) in all. First bought on \(first). Mostly from \(item.cafeName)."
    }

    private func unwrap() {
        withAnimation(.easeOut(duration: 0.3)) {
            isUnwrapped = true
        }
        confetti += 1
        // The foil's VoiceOver button goes with the foil, so say what was under it.
        UIAccessibility.post(notification: .announcement, argument: "Your number 1 is \(item.name).")
    }
}

private struct FavoritePagePreview: View {
    @State private var isUnwrapped = false

    var body: some View {
        if let item = CafeWrapped.sample.favorite {
            FavoritePage(item: item, isActive: true, initialTaps: 0, isUnwrapped: $isUnwrapped)
                .foregroundStyle(.white)
                .background(Color(hex: 0x2E1A87))
        }
    }
}

#Preview {
    FavoritePagePreview()
}
