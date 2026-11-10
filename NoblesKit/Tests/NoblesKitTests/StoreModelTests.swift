import Foundation
import Testing
@testable import NoblesKit

struct StoreModelTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func statement() throws -> StoreStatement {
        try StoreService.parse(Fixture.data("synthetic-store-charges.json"), fetchedAt: now)
    }

    // MARK: Fixture

    @Test func parsesTheFixture() throws {
        let statement = try statement()

        #expect(statement.charges.count == 29)
        #expect(statement.totalsByStore.count == 3)
        #expect(statement.stores == ["Athletic Store", "Cafe 2000", "Cafe at Gleason Hall"])
        #expect(statement.grandTotal == Decimal(string: "222.19"))
        #expect(statement.grandTotal.usd() == "$222.19")
        #expect(statement.fetchedAt == now)

        // Newest first, oldest last.
        #expect(statement.charges.first?.id == 447649)
        #expect(statement.charges.last?.id == 433123)
        #expect(zip(statement.charges, statement.charges.dropFirst()).allSatisfy { $0.madeAt >= $1.madeAt })

        // The source's totals are the sums of its charges.
        for total in statement.totalsByStore {
            #expect(total.total == statement.charges(in: [total.storeName]).reduce(0) { $0 + $1.total })
        }
        #expect(statement.grandTotal == statement.charges.reduce(0) { $0 + $1.total })
    }

    @Test func parsesChargeFields() throws {
        let charges = try statement().charges

        let newest = try #require(charges.first)
        #expect(newest.id == 447649)
        #expect(newest.storeName == "Cafe at Gleason Hall")
        #expect(newest.transactionType == "Chit")
        #expect(newest.detail == "Turkey & Swiss Panini")
        #expect(newest.quantity == 1)
        #expect(newest.amount == Decimal(string: "6.00"))
        #expect(newest.tax == 0)
        #expect(newest.madeAt == LocalDate(2026, 11, 9).at(hour: 10, minute: 12)) // "15:12" UTC
        #expect(newest.postedOn == nil)
        #expect(newest.isPending)
        #expect(charges.filter(\.isPending).map(\.id) == [447649, 447281, 446936]) // only the newest

        let posted = try #require(charges.first { $0.id == 446241 })
        #expect(posted.postedOn == LocalDate(2026, 11, 3))
        #expect(!posted.isPending)

        let socks = try #require(charges.first { $0.storeName == "Athletic Store" })
        #expect(socks.detail == "Athletic Socks")
        #expect(socks.amount == Decimal(string: "15.00"))
        #expect(socks.madeAt == LocalDate(2026, 10, 27).at(hour: 17, minute: 8)) // "21:08" UTC

        // `total_cost` is the whole line, so a quantity of two is already counted in the amount.
        let pair = try #require(charges.first { $0.id == 442055 })
        #expect(pair.detail == "Iced Tea")
        #expect(pair.quantity == 2)
        #expect(pair.amount == Decimal(string: "3.50"))
    }

    @Test func parsesSalesTax() throws {
        let statement = try statement()

        let taxed = try #require(statement.charges.first { $0.tax > 0 })
        #expect(statement.charges.filter { $0.tax > 0 }.count == 1)
        #expect(taxed.detail == "Team Practice Shorts")
        #expect(taxed.amount == Decimal(string: "27.00"))
        #expect(taxed.tax == Decimal(string: "1.69"))
        #expect(taxed.total == Decimal(string: "28.69"))

        let athletic = try #require(statement.totalsByStore.first { $0.storeName == "Athletic Store" })
        #expect(athletic.amount == Decimal(string: "102.00"))
        #expect(athletic.tax == Decimal(string: "1.69"))
        #expect(athletic.total == Decimal(string: "103.69"))
    }

    @Test func statementHelpersFilterAndTotal() throws {
        let statement = try statement()

        #expect(statement.charges(in: ["Athletic Store"]).map(\.detail)
            == ["Athletic Socks", "Nobles Quarter-Zip", "Team Practice Shorts"])
        #expect(statement.charges(in: ["cafe 2000"]).count == 4) // case-insensitive
        #expect(statement.total(in: ["Cafe 2000"]) == Decimal(string: "11.50"))
        #expect(statement.total(in: ["Athletic Store", "Cafe 2000"]) == Decimal(string: "115.19"))
        #expect(statement.total(in: []) == statement.grandTotal)
        #expect(statement.latestCharge()?.id == 447649)
        #expect(statement.latestCharge(in: ["Cafe 2000"])?.detail == "Soft Pretzel")
        #expect(statement.latestCharge(in: ["Nowhere"]) == nil)
    }

    @Test func fixtureTimesFallInsideCafeHours() throws {
        let cafeCharges = try statement().charges.filter { CafeWrapped.isCafe($0.storeName) }
        #expect(cafeCharges.count == 26)
        for charge in cafeCharges {
            #expect(CafeMenus.isDuringHours(charge), "\(charge.id)")
        }
    }

    // MARK: Times

    @Test func readsCreatedTimesAsUTC() throws {
        let body = """
        {"ok": true, "charges": [{"charge_id": 1, "store_name": "Cafe 2000", "description": "Doritos",
        "quantity": 1, "total_cost": "2.00", "sales_tax": "0.00", "created": "2026-11-10 01:30", "posted_on": null}]}
        """
        let charge = try #require(try StoreService.parse(Data(body.utf8), fetchedAt: now).charges.first)

        // 1:30 AM UTC on Tuesday is 8:30 PM on Monday in school time.
        #expect(charge.madeAt == LocalDate(2026, 11, 9).at(hour: 20, minute: 30))
        #expect(LocalDate(charge.madeAt) == LocalDate(2026, 11, 9))
        #expect(Calendar.school.component(.hour, from: charge.madeAt) == 20)
    }

    @Test func readsCreatedTimesAcrossTheDaylightSavingChange() {
        // Daylight saving time ends on Sunday, Nov 1: 14:00 UTC is 10 AM before it and 9 AM after.
        #expect(StoreChargesParsing.date(from: "2026-10-30 14:00") == LocalDate(2026, 10, 30).at(hour: 10))
        #expect(StoreChargesParsing.date(from: "2026-11-02 14:00") == LocalDate(2026, 11, 2).at(hour: 9))
        // So a 10 AM purchase is written an hour later after the change.
        #expect(StoreChargesParsing.date(from: "2026-11-02 15:00") == LocalDate(2026, 11, 2).at(hour: 10))
    }

    @Test func readsCreatedStampsLeniently() {
        #expect(StoreChargesParsing.date(from: " 2026-11-09 15:12 ") == LocalDate(2026, 11, 9).at(hour: 10, minute: 12))
        #expect(StoreChargesParsing.date(from: "2026-11-09 15") == LocalDate(2026, 11, 9).at(hour: 10))
        // Without a time, the day stays put.
        #expect(StoreChargesParsing.date(from: "2026-11-09") == LocalDate(2026, 11, 9).startOfDay())
        #expect(StoreChargesParsing.date(from: "2026-11-09 noon") == LocalDate(2026, 11, 9).startOfDay())
        #expect(StoreChargesParsing.date(from: "yesterday") == nil)
    }

    // MARK: Money and configuration

    @Test func formatsMoney() {
        #expect(Decimal(string: "4.00")!.usd() == "$4.00")
        #expect(Decimal(string: "3.5")!.usd() == "$3.50")
        #expect(Decimal(string: "222.75")!.usd(showsCents: false) == "$223")
        // Half-up, not NumberFormatter's default half-even.
        #expect(Decimal(string: "222.50")!.usd(showsCents: false) == "$223")
        #expect(Decimal(string: "0.125")!.usd() == "$0.13")
    }

    @Test func configurationDecodesLeniently() throws {
        func decode(_ json: String) throws -> StoreConfiguration {
            try JSONDecoder().decode(StoreConfiguration.self, from: Data(json.utf8))
        }

        let empty = try decode("{}")
        #expect(empty.stores.isEmpty)
        #expect(empty.highlight == .totalSpent)
        #expect(empty.limit == nil)
        #expect(empty.showsRecentCharges)

        let bad = try decode(#"{"highlight":"nonsense","limit":"oops"}"#)
        #expect(bad.highlight == .totalSpent) // unknown case falls back to the default
        #expect(bad.limit == nil)

        let set = try decode(#"{"highlight":"remaining","limit":50,"stores":["Cafe 2000"],"showsRecentCharges":false}"#)
        #expect(set.highlight == .remaining)
        #expect(set.limit == Decimal(50))
        #expect(set.stores == ["Cafe 2000"])
        #expect(!set.showsRecentCharges)
    }

    // MARK: Sample

    @Test func sampleIsStableForAFixedNow() throws {
        let fixed = LocalDate(2026, 11, 9).at(hour: 12)

        #expect(StoreStatement.sample(now: fixed) == StoreStatement.sample(now: fixed))
        let sample = StoreStatement.sample(now: fixed)
        #expect(sample.charges.count == 24)
        #expect(sample.stores == ["Athletic Store", "Cafe 2000", "Cafe at Gleason Hall"])
        #expect(sample.grandTotal == Decimal(string: "151.75"))
        #expect(sample.charges.filter(\.isPending).count == 2)

        // The gallery's Lock Screen stress case: this morning's pending charge, with a long name.
        let newest = try #require(sample.latestCharge())
        #expect(newest.detail == "Egg, Bacon, American on Croissant")
        #expect(newest.amount == Decimal(string: "5.00"))
        #expect(newest.madeAt == LocalDate(fixed).at(hour: 10, minute: 41))
        #expect(newest.isPending)
    }

    @Test func sampleBuysRealItemsOnSchoolDays() {
        let tuesday = LocalDate(2026, 10, 27).at(hour: 11, minute: 30) // the gallery's moment
        for now in [tuesday, LocalDate(2026, 11, 14).at(hour: 12)] {
            let sample = StoreStatement.sample(now: now)
            let today = LocalDate(now)
            // Today's charge, then the rest on the school days before today.
            #expect(sample.charges.first.map { LocalDate($0.madeAt) } == today)
            let earlier = sample.charges.dropFirst()
            #expect(earlier.allSatisfy { LocalDate($0.madeAt) < today })
            #expect(earlier.allSatisfy { SchoolCalendar.nobles2026_27.isSchoolDay(LocalDate($0.madeAt)) })
            for charge in sample.charges where CafeWrapped.isCafe(charge.storeName) {
                #expect(CafeMenus.isOnMenu(charge), "\(charge.detail)")
            }
            for charge in earlier where CafeWrapped.isCafe(charge.storeName) {
                #expect(CafeMenus.isDuringHours(charge), "\(charge.detail)")
            }
        }
        #expect(StoreStatement.sample(now: tuesday).charges.first.map(CafeMenus.isDuringHours) == true)
    }
}
