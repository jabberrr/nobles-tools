import SwiftUI
import NoblesKit

/// Cafe Wrapped: a semester of cafe purchases told as a story of full-screen pages.
///
/// Tap the right of the screen for the next page and the left for the one before; nothing advances
/// on its own. Each page arrives hidden, then plays its reveals (again on a revisit), over a
/// backdrop that cross-fades to the page's colors. Anything on a page with its own tap handling
/// (the favorite's foil, the persona card, buttons) takes taps on it first.
struct CafeWrappedView: View {
    let wrapped: CafeWrapped
    /// Where the recap's streak stands among other students', once known.
    let streakStanding: StreakStanding?

    @State private var index: Int
    /// The page whose reveals are playing. It follows `position` a moment later, so a page always
    /// arrives hidden and then reveals itself.
    @State private var revealedIndex: Int?
    @State private var isMovingForward = true
    /// Kept across visits, so going back to the favorite doesn't wrap it up again.
    @State private var isFavoriteUnwrapped: Bool
    /// Kept across visits, so going back to the persona doesn't turn its card face down again.
    @State private var isPersonaRevealed = false
    private let initialFoilTaps: Int

    @AccessibilityFocusState private var isPageFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wrappedIsStatic) private var isStatic

    /// - Parameters:
    ///   - streakStanding: Where the streak stands among other students'; `nil` hides that line.
    ///   - startPage: The page to open on; the first page if `wrapped` has nothing for it.
    ///   - favoriteTaps: Taps already made on the favorite's foil, for snapshots.
    ///     `FavoritePage.tapsToUnwrap` or more opens it unwrapped.
    init(wrapped: CafeWrapped, streakStanding: StreakStanding? = nil, startPage: WrappedPage = .intro, favoriteTaps: Int = 0) {
        self.wrapped = wrapped
        self.streakStanding = streakStanding
        _index = State(initialValue: WrappedPage.pages(for: wrapped).firstIndex(of: startPage) ?? 0)
        _isFavoriteUnwrapped = State(initialValue: favoriteTaps >= FavoritePage.tapsToUnwrap)
        initialFoilTaps = favoriteTaps
    }

    private var pages: [WrappedPage] { WrappedPage.pages(for: wrapped) }

    /// `index`, kept in range should a new recap have fewer pages.
    private var position: Int { min(index, pages.count - 1) }

    var body: some View {
        let page = pages[position]
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                ZStack {
                    pageView(page)
                        .id(page)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                go(by: location.x < proxy.size.width * 0.35 ? -1 : 1)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .background {
            WrappedBackground(colors: page.colors)
                .ignoresSafeArea()
        }
        .statusBarHidden()
        .sensoryFeedback(.selection, trigger: index)
        .task(id: position) {
            revealedIndex = position
            isPageFocused = true
        }
    }

    // MARK: Pages

    /// A page as VoiceOver reads it: one summary, except where it holds controls of its own (the
    /// favorite's foil, the summary's buttons).
    @ViewBuilder
    private func pageView(_ page: WrappedPage) -> some View {
        let view = content(of: page, isActive: isStatic || revealedIndex == position)
            .accessibilityElement(children: page == .favorite || page == .summary ? .contain : .ignore)
            .accessibilityLabel(page.accessibilitySummary(for: wrapped, standing: streakStanding))
            .accessibilityValue("Page \(position + 1) of \(pages.count)")
            .accessibilityAction { go(by: 1) }
            .accessibilityAction(named: "Next") { go(by: 1) }
            .accessibilityAction(named: "Previous") { go(by: -1) }
        if isStatic {
            // `ImageRenderer` draws nothing at all for a view with `accessibilityFocused`.
            view
        } else {
            view.accessibilityFocused($isPageFocused)
        }
    }

    @ViewBuilder
    private func content(of page: WrappedPage, isActive: Bool) -> some View {
        switch page {
        case .intro:
            IntroPage(wrapped: wrapped, isActive: isActive)
        case .total:
            TotalPage(wrapped: wrapped, isActive: isActive)
        case .cafes:
            CafesPage(wrapped: wrapped, isActive: isActive)
        case .topItems:
            TopItemsPage(wrapped: wrapped, isActive: isActive)
        case .favorite:
            if let item = wrapped.favorite {
                FavoritePage(
                    item: item,
                    share: WrappedFormat.fraction(item.total, of: wrapped.total),
                    isActive: isActive,
                    initialTaps: initialFoilTaps,
                    isUnwrapped: $isFavoriteUnwrapped
                )
            }
        case .times:
            TimesPage(wrapped: wrapped, isActive: isActive)
        case .days:
            DaysPage(wrapped: wrapped, isActive: isActive)
        case .records:
            RecordsPage(wrapped: wrapped, isActive: isActive, standing: streakStanding)
        case .persona:
            PersonaPage(wrapped: wrapped, isActive: isActive, isRevealed: $isPersonaRevealed)
        case .summary:
            SummaryPage(wrapped: wrapped, isActive: isActive) { dismiss() }
        }
    }

    // MARK: Chrome

    private var header: some View {
        VStack(spacing: 6) {
            progressBar
            HStack {
                Label(wrapped.period.name, systemImage: "gift.fill")
                    .font(WrappedStyle.strongCaption)
                    .foregroundStyle(WrappedStyle.secondary)
                    .accessibilityHidden(true)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(WrappedStyle.symbol(15))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.18), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// One segment per page: those before the current one full, the current one filling as it
    /// arrives.
    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(pages.indices, id: \.self) { segment in
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.white)
                                .frame(width: segment <= position ? proxy.size.width : 0)
                        }
                    }
                    .clipShape(Capsule())
            }
        }
        .frame(height: 4)
        .animation(isStatic ? nil : .easeOut(duration: 0.35), value: position)
        .accessibilityHidden(true)
    }

    // MARK: Navigation

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertion = AnyTransition.opacity
            .combined(with: .offset(x: isMovingForward ? 80 : -80))
            .combined(with: .scale(scale: 0.94))
        return .asymmetric(insertion: insertion, removal: .opacity.combined(with: .scale(scale: 1.04)))
    }

    private func go(by step: Int) {
        let target = position + step
        guard pages.indices.contains(target) else { return }
        isMovingForward = step > 0
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.5, bounce: 0.15)) {
            index = target
        }
    }
}

#Preview("Cafe Wrapped") {
    CafeWrappedView(wrapped: .sample, streakStanding: .sample)
}

#Preview("Favorite, half unwrapped") {
    CafeWrappedView(wrapped: .sample, startPage: .favorite, favoriteTaps: 2)
}
