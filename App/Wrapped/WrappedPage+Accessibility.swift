import Foundation
import NoblesKit

extension WrappedPage {
    /// What VoiceOver reads for the page: its story in a sentence or two.
    func accessibilitySummary(for wrapped: CafeWrapped) -> String {
        switch self {
        case .intro: "\(WrappedFormat.period(wrapped.period)): Cafe Wrapped, your semester at the cafes."
        case .total: Self.totalSummary(wrapped)
        case .cafes: Self.cafesSummary(wrapped)
        case .topItems: Self.topItemsSummary(wrapped)
        case .favorite: Self.favoriteSummary(wrapped)
        case .times: Self.timesSummary(wrapped)
        case .days: Self.daysSummary(wrapped)
        case .records: Self.recordsSummary(wrapped)
        case .persona: "Your cafe personality: \(wrapped.persona.title). \(wrapped.persona.tagline)"
        case .summary: "That's a wrap."
        }
    }

    private static func totalSummary(_ wrapped: CafeWrapped) -> String {
        let purchases = WrappedFormat.count(wrapped.purchaseCount, "cafe purchase")
        let days = WrappedFormat.count(wrapped.dayCount, "day")
        return "You spent \(wrapped.total.usd()) on \(purchases) across \(days), \(wrapped.averagePerDay.usd()) a day."
    }

    private static func cafesSummary(_ wrapped: CafeWrapped) -> String {
        let lines: [String] = wrapped.cafes.map { cafe in
            let goTo = cafe.topItem.map { " Your go-to: \($0.name)." } ?? ""
            return "\(cafe.name): \(cafe.total.usd()), \(WrappedFormat.percent(cafe.share)) of your spending, \(WrappedFormat.count(cafe.purchaseCount, "purchase")).\(goTo)"
        }
        return (["Where you went."] + lines).joined(separator: " ")
    }

    private static func topItemsSummary(_ wrapped: CafeWrapped) -> String {
        let lines: [String] = wrapped.topItems.enumerated().map { rank, item in
            "Number \(rank + 1): \(item.name), \(WrappedFormat.count(item.count, "time"))."
        }
        return (["Your top \(wrapped.topItems.count)."] + lines).joined(separator: " ")
    }

    private static func favoriteSummary(_ wrapped: CafeWrapped) -> String {
        guard let item = wrapped.favorite else { return "" }
        let first = WrappedFormat.day(LocalDate(item.firstBought))
        return "Your number 1: \(item.name). You got it \(WrappedFormat.count(item.count, "time")), \(item.total.usd()) in all. First one: \(first)."
    }

    private static func timesSummary(_ wrapped: CafeWrapped) -> String {
        guard let peak = wrapped.peakHour else { return "" }
        let title = wrapped.timeOfDay.map { "\($0.title). " } ?? ""
        let count = WrappedFormat.count(wrapped.hourCounts[peak], "purchase")
        return "\(title)Your busiest hour was between \(WrappedFormat.hourSpan(peak)), with \(count)."
    }

    private static func daysSummary(_ wrapped: CafeWrapped) -> String {
        var parts: [String] = []
        if let weekday = wrapped.favoriteWeekday {
            parts.append("\(WrappedFormat.weekday(weekday))s were your day.")
        }
        if let day = wrapped.biggestDay {
            parts.append("Your biggest day: \(WrappedFormat.day(day.date)), \(day.total.usd()) on \(WrappedFormat.count(day.itemCount, "item")).")
        }
        return parts.joined(separator: " ")
    }

    private static func recordsSummary(_ wrapped: CafeWrapped) -> String {
        var parts = ["Personal bests."]
        if let streak = wrapped.longestStreak, streak.length > 1 {
            parts.append("\(streak.length) days in a row, \(WrappedFormat.shortDay(streak.start)) to \(WrappedFormat.shortDay(streak.end)).")
        }
        if wrapped.distinctItemCount > 1 {
            parts.append("You tried \(wrapped.distinctItemCount) different things.")
        }
        if let charge = wrapped.biggestPurchase {
            parts.append("Biggest single buy: \(charge.total.usd()), \(charge.detail).")
        }
        if let charge = wrapped.firstPurchase {
            parts.append("First of the semester: \(charge.detail), \(WrappedFormat.moment(charge.madeAt)).")
        }
        return parts.joined(separator: " ")
    }
}
