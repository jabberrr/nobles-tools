import Foundation
import Testing
@testable import NoblesKit

struct ZZProbeTests {
    @Test func probe() throws {
        let w = CafeWrapped.sample
        var out = ""
        func p(_ s: String) { out += s + "\n" }
        p("total \(w.total) purchases \(w.purchaseCount) items \(w.itemCount) days \(w.dayCount) distinct \(w.distinctItemCount) avg \(w.averagePerDay)")
        p("top: " + w.topItems.map { "\($0.name) \($0.emoji) \($0.productImage ?? "-") x\($0.count) $\($0.total) @\($0.cafeName)" }.joined(separator: " | "))
        for c in w.cafes { p("cafe \(c.name) $\(c.total) n\(c.purchaseCount) d\(c.dayCount) share \(c.share): " + c.topItems.map { "\($0.name) x\($0.count) $\($0.total)" }.joined(separator: ", ")) }
        p("hours \(w.hourCounts)")
        p("weekdays \(w.weekdayCounts) fav \(w.favoriteWeekday ?? -1) peak \(w.peakHour ?? -1) tod \(String(describing: w.timeOfDay))")
        p("months " + w.months.map { "\($0.name) $\($0.total) n\($0.purchaseCount)" }.joined(separator: ", "))
        p("biggestDay \(String(describing: w.biggestDay))")
        p("biggestPurchase \(w.biggestPurchase.map { "\($0.detail) x\($0.quantity) $\($0.total) \(LocalDate($0.madeAt))" } ?? "-")")
        p("streak \(String(describing: w.longestStreak))")
        p("first \(w.firstPurchase.map { "\($0.detail) \($0.madeAt)" } ?? "-")")
        p("persona \(w.persona)")
        let span = w.period.span
        let s = StoreStatement.wrappedSample(semester: span, through: span.end, fetchedAt: span.end.at(hour: 23))
        p("charges \(s.charges.count) grand \(s.grandTotal) stores \(s.stores)")
        let items = Dictionary(grouping: s.charges.filter { CafeWrapped.isCafe($0.storeName) }, by: \.detail).mapValues { $0.reduce(0) { $0 + $1.quantity } }
        p("items " + items.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
        let dayTotals = w.days.sorted { $0.total > $1.total }.prefix(5).map { "\($0.date) $\($0.total)" }
        p("top days \(dayTotals)")
        let schoolDays = SchoolCalendar.nobles2026_27.countedDays(in: span, counting: .schoolDays)
        p("schoolDays \(schoolDays) early \(w.hourCounts[..<10].reduce(0,+)) evening \(w.hourCounts[17...].reduce(0,+))")
        let sp = StoreStatement.sample(now: LocalDate(2026, 10, 27).at(hour: 11, minute: 30))
        p("spending \(sp.charges.count) grand \(sp.grandTotal) newest \(sp.charges.first!.detail) \(sp.charges.first!.madeAt) oldest \(LocalDate(sp.charges.last!.madeAt))")
        p("totals " + sp.totalsByStore.map { "\($0.storeName) \($0.total)" }.joined(separator: ", "))
        print("PROBE\n" + out + "END")
    }
}
