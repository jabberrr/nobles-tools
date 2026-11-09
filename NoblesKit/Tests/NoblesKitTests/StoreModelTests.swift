import Foundation
import Testing
@testable import NoblesKit

struct StoreModelTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)

    private func statement() throws -> StoreStatement {
        try StoreService.parse(Fixture.data("real-store-charges.json"), fetchedAt: now)
    }

    // MARK: Fixture

    @Test func parsesTheRealFixture() throws {
        let statement = try statement()

        #expect(statement.charges.count == 26)
        #expect(statement.totalsByStore.count == 3)
        #expect(statement.stores == ["Athletic Store", "Cafe 2000", "Cafe at Gleason Hall"])
        #expect(statement.grandTotal == Decimal(string: "136.75"))
        #expect(statement.grandTotal.usd() == "$136.75")
        #expect(statement.fetchedAt == now)

        // Newest first, oldest last.
        #expect(statement.charges.first?.id == 655959)
        #expect(statement.charges.last?.id == 631716)
        #expect(zip(statement.charges, statement.charges.dropFirst()).allSatisfy { $0.madeAt >= $1.madeAt })
    }

    @Test func parsesChargeFields() throws {
        let charges = try statement().charges

        let newest = try #require(charges.first)
        #expect(newest.id == 655959)
        #expect(newest.storeName == "Cafe at Gleason Hall")
        #expect(newest.transactionType == "Chit")
        #expect(newest.detail == "Egg, Bacon, American on Croissant")
        #expect(newest.amount == Decimal(string: "4.00"))
        #expect(newest.tax == 0)
        #expect(newest.madeAt == LocalDate(2026, 11, 9).at(hour: 14, minute: 59))
        #expect(newest.postedOn == nil)
        #expect(newest.isPending)

        let posted = try #require(charges.first { $0.id == 653097 })
        #expect(posted.postedOn == LocalDate(2026, 10, 29))
        #expect(!posted.isPending)

        let shirt = try #require(charges.first { $0.storeName == "Athletic Store" })
        #expect(shirt.detail == "UA MENS")
        #expect(shirt.amount == Decimal(string: "55.00"))
        #expect(shirt.madeAt == LocalDate(2026, 10, 6).at(hour: 21, minute: 3))
    }

    @Test func statementHelpersFilterAndTotal() throws {
        let statement = try statement()

        #expect(statement.charges(in: ["Athletic Store"]).map(\.detail) == ["UA MENS"])
        #expect(statement.charges(in: ["cafe 2000"]).count == 4) // case-insensitive
        #expect(statement.total(in: ["Cafe 2000"]) == Decimal(string: "9.75"))
        #expect(statement.total(in: ["Athletic Store", "Cafe 2000"]) == Decimal(string: "64.75"))
        #expect(statement.total(in: []) == statement.grandTotal)
        #expect(statement.latestCharge()?.id == 655959)
        #expect(statement.latestCharge(in: ["Cafe 2000"])?.detail == "RX Bar")
        #expect(statement.latestCharge(in: ["Nowhere"]) == nil)
    }

    // MARK: Money and configuration

    @Test func formatsMoney() {
        #expect(Decimal(string: "4.00")!.usd() == "$4.00")
        #expect(Decimal(string: "3.5")!.usd() == "$3.50")
        #expect(Decimal(string: "136.75")!.usd(showsCents: false) == "$137")
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

    @Test func sampleIsStableForAFixedNow() {
        let fixed = LocalDate(2026, 11, 9).at(hour: 12)

        #expect(StoreStatement.sample(now: fixed) == StoreStatement.sample(now: fixed))
        let sample = StoreStatement.sample(now: fixed)
        #expect(sample.charges.count == 26)
        #expect(sample.stores == ["Athletic Store", "Cafe 2000", "Cafe at Gleason Hall"])
        #expect(sample.grandTotal == Decimal(string: "136.75"))
        #expect(sample.charges.contains { $0.isPending })
    }
}
