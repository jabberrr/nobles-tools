import SwiftUI
import NoblesKit

/// Every page of Cafe Wrapped in its finished state, phone-sized: the sample recap (the favorite
/// covered, part-torn and unwrapped), a sparse recap, the tallest pages on a small iPhone
/// ("-compact"), the empty state and the share poster. Rendered to `docs/widgets` by the
/// `WidgetSnapshots` tests so layouts can be checked without a device.
@MainActor
enum WrappedGallery {
    static var entries: [WidgetGallery.Entry] {
        let sample = CafeWrapped.sample
        var entries = WrappedPage.pages(for: sample).flatMap { page in
            page == .favorite ? favoriteEntries(sample) : [entry("wrapped-\(page.galleryName)", sample, page)]
        }
        if let sparse = Self.sparse {
            entries += [WrappedPage.total, .cafes, .topItems, .records, .summary].map { page in
                entry("wrapped-sparse-\(page.galleryName)", sparse, page)
            }
        }
        entries += [WrappedPage.total, .cafes, .topItems, .records].map { page in
            entry("wrapped-compact-\(page.galleryName)", sample, page, screen: .compact)
        }
        entries.append(entry(
            "wrapped-compact-\(WrappedPage.favorite.galleryName)-unwrapped",
            sample,
            .favorite,
            favoriteTaps: FavoritePage.tapsToUnwrap,
            screen: .compact
        ))
        entries.append(phone("wrapped-empty", .large) {
            WrappedMessageView(message: .noPurchases(in: sample.period.name), onSample: {}, onClose: {})
        })
        // TEMPORARY: a page outside the story container, to diagnose blank renders.
        entries.append(phone("wrapped-debug-intro-direct", .large) {
            IntroPage(wrapped: sample, isActive: true)
                .foregroundStyle(.white)
                .background(Color(hex: 0x2A0A5E))
        })
        entries.append(WidgetGallery.Entry(name: "wrapped-poster", view: AnyView(WrappedPoster(wrapped: sample, cornerRadius: 0))))
        return entries
    }

    /// The favorite before a tap, three taps in, and unwrapped.
    private static func favoriteEntries(_ wrapped: CafeWrapped) -> [WidgetGallery.Entry] {
        let name = "wrapped-\(WrappedPage.favorite.galleryName)"
        return [
            entry("\(name)-covered", wrapped, .favorite),
            entry("\(name)-torn", wrapped, .favorite, favoriteTaps: 3),
            entry("\(name)-unwrapped", wrapped, .favorite, favoriteTaps: FavoritePage.tapsToUnwrap),
        ]
    }

    /// A thin semester as of the gallery's day: one cafe, three items over three days in one
    /// month, no streak, and an athletic-store charge that doesn't count.
    private static var sparse: CafeWrapped? {
        let calendar = SchoolCalendar.nobles2026_27
        let today = LocalDate(WidgetGallery.now)
        guard let semester = CafeWrapped.semester(in: calendar, on: today) else { return nil }
        func charge(_ id: Int, _ store: String, _ item: String, _ amount: String, _ day: Int, _ hour: Int, _ minute: Int) -> StoreCharge {
            let date = LocalDate(year: 2026, month: 10, day: day)
            return StoreCharge(
                id: id,
                storeName: store,
                transactionType: "Chit",
                detail: item,
                amount: Decimal(string: amount) ?? 0,
                madeAt: date.at(hour: hour, minute: minute),
                postedOn: date
            )
        }
        let charges = [
            charge(5, "Cafe at Gleason Hall", "Roasted Turkey & Cheddar Panini with Pesto", "7.25", 22, 12, 41),
            charge(4, "Athletic Store", "Nobles Crew Sweatshirt", "56.00", 20, 16, 5),
            charge(3, "Cafe at Gleason Hall", "Everything Bagel with Cream Cheese", "3.25", 14, 10, 32),
            charge(2, "Cafe at Gleason Hall", "Iced Vanilla Latte", "4.75", 6, 10, 21),
            charge(1, "Cafe at Gleason Hall", "Everything Bagel with Cream Cheese", "3.25", 6, 10, 20),
        ]
        let statement = StoreStatement(
            charges: charges,
            totalsByStore: [
                StoreTotal(storeName: "Cafe at Gleason Hall", amount: 18.50, total: 18.50),
                StoreTotal(storeName: "Athletic Store", amount: 56, total: 56),
            ],
            grandTotal: 74.50,
            fetchedAt: WidgetGallery.now
        )
        return CafeWrapped(statement: statement, semester: semester, calendar: calendar, asOf: today)
    }

    // MARK: Drawing

    /// The iPhone a page is drawn on, with the safe-area insets `ImageRenderer` doesn't have.
    private enum Screen {
        /// A 6.1-inch iPhone with a Dynamic Island.
        case large
        /// An iPhone SE.
        case compact

        var size: CGSize {
            switch self {
            case .large: CGSize(width: 393, height: 852)
            case .compact: CGSize(width: 375, height: 667)
            }
        }

        var safeArea: EdgeInsets {
            switch self {
            case .large: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
            case .compact: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
            }
        }
    }

    private static func entry(
        _ name: String,
        _ wrapped: CafeWrapped,
        _ page: WrappedPage,
        favoriteTaps: Int = 0,
        screen: Screen = .large
    ) -> WidgetGallery.Entry {
        phone(name, screen) {
            CafeWrappedView(wrapped: wrapped, startPage: page, favoriteTaps: favoriteTaps)
        }
    }

    private static func phone<Content: View>(_ name: String, _ screen: Screen, @ViewBuilder content: () -> Content) -> WidgetGallery.Entry {
        let view = content()
            .safeAreaPadding(screen.safeArea)
            .frame(width: screen.size.width, height: screen.size.height)
            .environment(\.wrappedIsStatic, true)
        return WidgetGallery.Entry(name: name, view: AnyView(view))
    }
}

#Preview("Cafe Wrapped gallery") {
    ScrollView {
        VStack(spacing: 8) {
            ForEach(WrappedGallery.entries) { entry in
                entry.view
                    .scaleEffect(0.5)
                    .frame(width: 200, height: 430)
                Text(entry.name).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
