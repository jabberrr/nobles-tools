import SwiftUI
import UIKit
import NoblesKit

/// The reveal of #1: its picture under foil that opens in stages, one per tap, then confetti, its
/// name and its numbers set as type between hairlines. Taps on the foil open it; taps anywhere
/// else still turn the page. VoiceOver finds the foil as a button and, once it's off, the item in
/// one sentence.
struct FavoritePage: View {
    /// Taps it takes to get the foil off: one per stage.
    static let tapsToUnwrap = 4

    let item: CafeWrapped.Item
    /// The item's share of the semester's spending, 0...1.
    let share: Double
    let isActive: Bool
    @Binding var isUnwrapped: Bool
    private let initialTaps: Int

    /// Taps made on the foil so far, for the dots that count down.
    @State private var taps: Int
    /// Whether this visit began wrapped. The foil then stays in place once it's off, so its last
    /// stage plays out; a visit that begins unwrapped shows the plain picture.
    @State private var beganWrapped: Bool
    @State private var confetti = 0

    init(item: CafeWrapped.Item, share: Double, isActive: Bool, initialTaps: Int, isUnwrapped: Binding<Bool>) {
        self.item = item
        self.share = share
        self.isActive = isActive
        self.initialTaps = initialTaps
        _isUnwrapped = isUnwrapped
        _taps = State(initialValue: initialTaps)
        _beganWrapped = State(initialValue: !isUnwrapped.wrappedValue)
    }

    var body: some View {
        ZStack {
            // Spaced to fit the details under the picture on a 375 × 667 pt iPhone.
            VStack(spacing: 0) {
                WrappedEyebrow("Your #1", symbol: "crown.fill")
                    .wrappedReveal(isActive, delay: 0.1, style: .fade)
                Spacer(minLength: 12)
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
                .padding(.top, 20)
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
            Text("Tap the foil to open it")
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

    /// Hidden until the foil is off; then the name pops, the rules draw across and each figure
    /// and fact rises in turn.
    private var details: some View {
        let isRevealed = isActive && isUnwrapped
        return VStack(spacing: 16) {
            Text(item.name)
                .font(WrappedStyle.hero(28))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .wrappedReveal(isRevealed, delay: 0.35, style: .pop)
            VStack(spacing: 0) {
                WrappedRule()
                    .wrappedReveal(isRevealed, delay: 0.6, style: .growRight)
                figures(isRevealed: isRevealed)
                WrappedRule()
                    .wrappedReveal(isRevealed, delay: 1.2, style: .growRight)
                fact("First bought", WrappedFormat.day(LocalDate(item.firstBought)))
                    .wrappedReveal(isRevealed, delay: 1.3)
                WrappedRule()
                    .wrappedReveal(isRevealed, delay: 1.4, style: .growRight)
                fact("Usual cafe", item.cafeName)
                    .wrappedReveal(isRevealed, delay: 1.5)
            }
        }
    }

    /// Times bought, spent on it and its share of all spending, in columns split by hairlines.
    private func figures(isRevealed: Bool) -> some View {
        HStack(spacing: 0) {
            column(item.count == 1 ? "Time" : "Times") {
                CountingText(Double(item.count), isActive: isRevealed, duration: 1, delay: 0.8, format: WrappedFormat.whole)
            }
            .wrappedReveal(isRevealed, delay: 0.7)
            WrappedRule(axis: .vertical)
                .wrappedReveal(isRevealed, delay: 0.8, style: .fade)
            column("Spent") {
                CountingText(WrappedFormat.double(item.total), isActive: isRevealed, duration: 1.2, delay: 0.95, format: WrappedFormat.dollars)
            }
            .wrappedReveal(isRevealed, delay: 0.85)
            if share > 0 {
                WrappedRule(axis: .vertical)
                    .wrappedReveal(isRevealed, delay: 0.95, style: .fade)
                column("Of spending") {
                    CountingText(share, isActive: isRevealed, duration: 1.2, delay: 1.1, format: WrappedFormat.percent)
                }
                .wrappedReveal(isRevealed, delay: 1)
            }
        }
        // The vertical rules as tall as the figures.
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A figure over its label, centered in an equal share of the row. Sized so a figure like
    /// "$63.50" fits a third of a 375 pt wide iPhone.
    private func column<Figure: View>(_ label: String, @ViewBuilder figure: () -> Figure) -> some View {
        VStack(spacing: 2) {
            figure()
                .font(WrappedStyle.number(26))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            WrappedCardLabel(label)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    /// A label on the left and its value on the right, on one row.
    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            // At its full size: beside a short value, the row would otherwise scale it down.
            WrappedCardLabel(label)
                .fixedSize()
            Spacer(minLength: 0)
            Text(value)
                .font(WrappedStyle.itemName)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    /// What VoiceOver reads for the details.
    private var detailsDescription: String {
        let first = WrappedFormat.day(LocalDate(item.firstBought))
        let ofSpending = share > 0 ? ", \(WrappedFormat.percent(share)) of your spending" : ""
        return "\(item.name). You got it \(WrappedFormat.count(item.count, "time")), \(item.total.usd()) in all\(ofSpending). First bought on \(first). Mostly from \(item.cafeName)."
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
            FavoritePage(item: item, share: 0.15, isActive: true, initialTaps: 0, isUnwrapped: $isUnwrapped)
                .foregroundStyle(.white)
                .background(Color(hex: 0x2E1A87))
        }
    }
}

#Preview {
    FavoritePagePreview()
}
