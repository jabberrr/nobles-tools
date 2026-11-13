import SwiftUI
import NoblesKit

/// Every page of Cafe Wrapped in its finished state, phone-sized: the sample recap (with the sample
/// streak standing, and the favorite under foil, three stages open and unwrapped), a recap whose
/// #1 is a branded item with a product photo and whose purchases fall in two parts of the day
/// ("-branded"), a sparse recap with one part of the day and a one-purchase recap, the tallest
/// pages on a small iPhone ("-compact"), the empty and stopped-early messages, the persona
/// card face down, and the share poster. Rendered to `docs/widgets` by the `WidgetSnapshots`
/// tests so layouts can be checked without a device.
@MainActor
enum WrappedGallery {
    static var entries: [WidgetGallery.Entry] {
        let sample = CafeWrapped.sample
        var entries = WrappedPage.pages(for: sample).flatMap { page in
            page == .favorite ? favoriteEntries("wrapped", sample) : [entry("wrapped-\(page.galleryName)", sample, page, streakStanding: .sample)]
        }
        if let branded = Self.branded {
            entries += [WrappedPage.cafes, .topItems].map { page in
                entry("wrapped-branded-\(page.galleryName)", branded, page)
            }
            entries += favoriteEntries("wrapped-branded", branded)
            entries.append(entry("wrapped-branded-\(WrappedPage.times.galleryName)", branded, .times))
            entries.append(WidgetGallery.Entry(name: "wrapped-branded-poster", view: AnyView(WrappedPoster(wrapped: branded, cornerRadius: 0))))
        }
        if let sparse = Self.sparse {
            entries += [WrappedPage.total, .cafes, .topItems, .times, .records, .summary].map { page in
                entry("wrapped-sparse-\(page.galleryName)", sparse, page)
            }
        }
        if let single = Self.single {
            entries += [WrappedPage.total, .records].map { page in
                entry("wrapped-single-\(page.galleryName)", single, page)
            }
        }
        entries += [WrappedPage.total, .cafes, .topItems, .days, .records].map { page in
            entry("wrapped-compact-\(page.galleryName)", sample, page, streakStanding: .sample, screen: .compact)
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
        entries.append(phone("wrapped-stops-early", .large) {
            WrappedMessageView(
                message: .stopsEarly(at: LocalDate(year: 2026, month: 11, day: 10), isSignedOut: true),
                onSample: {},
                onClose: {}
            )
        })
        entries.append(phone("wrapped-\(WrappedPage.persona.galleryName)-card-back", .large) {
            PersonaCardBack(isShimmering: false)
                .frame(width: PersonaPage.cardSize.width, height: PersonaPage.cardSize.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { WrappedBackground(colors: WrappedPage.persona.colors).ignoresSafeArea() }
        })
        entries.append(WidgetGallery.Entry(name: "wrapped-poster", view: AnyView(WrappedPoster(wrapped: sample, cornerRadius: 0))))
        return entries
    }

    /// The favorite before a tap, three stages open, and unwrapped.
    private static func favoriteEntries(_ prefix: String, _ wrapped: CafeWrapped) -> [WidgetGallery.Entry] {
        let name = "\(prefix)-\(WrappedPage.favorite.galleryName)"
        return [
            entry("\(name)-covered", wrapped, .favorite),
            entry("\(name)-stage-3", wrapped, .favorite, favoriteTaps: 3),
            entry("\(name)-unwrapped", wrapped, .favorite, favoriteTaps: FavoritePage.tapsToUnwrap),
        ]
    }

    /// A thin semester as of the gallery's day: one cafe, three items over three mornings in one
    /// month, no streak, and an athletic-store charge that doesn't count.
    private static var sparse: CafeWrapped? {
        recap(of: [
            charge(5, gleason, "Egg, Bacon, American on Croissant", "5.50", day: 22, hour: 9, minute: 41),
            charge(4, "Athletic Store", "Nobles Crew Sweatshirt", "56.00", day: 20, hour: 16, minute: 5),
            charge(3, gleason, "Blueberry Crumb Muffin", "3.00", day: 14, hour: 10, minute: 32),
            charge(2, gleason, "Strawberry-Banana Smoothie", "3.00", day: 6, hour: 10, minute: 21),
            charge(1, gleason, "Blueberry Crumb Muffin", "3.00", day: 6, hour: 10, minute: 20),
        ])
    }

    /// A semester of one purchase, which is at once the first and the biggest.
    private static var single: CafeWrapped? {
        recap(of: [charge(1, cafe2000, "Jumbo Chocolate Chip Cookie", "2.50", day: 6, hour: 15, minute: 42)])
    }

    /// A month whose #1 is a branded item (Body Armor), with more branded items (Doritos, Oreo
    /// Cookies) among the rest, so product photos show under the foil, in the lists and on the
    /// poster. Every purchase is in the morning or the afternoon.
    private static var branded: CafeWrapped? {
        let orders: [(store: String, item: String, price: String, days: [Int])] = [
            (cafe2000, "Body Armor", "3.00", [5, 6, 7, 8, 13, 14, 15, 19, 20, 22]),
            (gleason, "Doritos", "3.00", [6, 8, 13, 20, 22, 26]),
            (cafe2000, "Jumbo Chocolate Chip Cookie", "2.50", [7, 14, 21, 26]),
            (gleason, "Oreo Cookies", "2.00", [9, 16, 23]),
            (cafe2000, "Whole Fruit", "1.25", [19, 21]),
            (gleason, "Blueberry Crumb Muffin", "3.00", [5]),
        ]
        var charges: [StoreCharge] = []
        for order in orders {
            for day in order.days {
                // Mornings at Gleason, afternoons at Cafe 2000, as the cafes are open.
                let hour = order.store == gleason ? 9 : 15
                charges.append(charge(charges.count + 1, order.store, order.item, order.price, day: day, hour: hour, minute: 5 + charges.count))
            }
        }
        return recap(of: charges)
    }

    private static let gleason = "Cafe at Gleason Hall"
    private static let cafe2000 = "Cafe 2000"

    /// The recap of `charges` as of the gallery's day.
    private static func recap(of charges: [StoreCharge]) -> CafeWrapped? {
        let calendar = SchoolCalendar.nobles2026_27
        let today = LocalDate(WidgetGallery.now)
        guard let semester = CafeWrapped.semester(in: calendar, on: today) else { return nil }
        let totals = Dictionary(grouping: charges, by: \.storeName).map { store, charges in
            StoreTotal(storeName: store, amount: charges.reduce(0) { $0 + $1.amount }, total: charges.reduce(0) { $0 + $1.total })
        }
        let statement = StoreStatement(
            charges: charges,
            totalsByStore: totals,
            grandTotal: totals.reduce(0) { $0 + $1.total },
            fetchedAt: WidgetGallery.now
        )
        return CafeWrapped(statement: statement, semester: semester, calendar: calendar, asOf: today)
    }

    /// A charge in October 2026.
    private static func charge(
        _ id: Int, _ store: String, _ item: String, _ amount: String, day: Int, hour: Int, minute: Int
    ) -> StoreCharge {
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
        streakStanding: StreakStanding? = nil,
        favoriteTaps: Int = 0,
        screen: Screen = .large
    ) -> WidgetGallery.Entry {
        phone(name, screen) {
            CafeWrappedView(wrapped: wrapped, streakStanding: streakStanding, startPage: page, favoriteTaps: favoriteTaps)
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
