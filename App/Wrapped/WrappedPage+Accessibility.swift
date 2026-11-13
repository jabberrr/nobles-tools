import Foundation
import NoblesKit

extension WrappedPage {
    /// What VoiceOver reads for the page: its story in a sentence or two. Like the pages, nothing
    /// before the favorite's page names the #1. `standing` is how the streak ranks among other
    /// students, once it's known.
    func accessibilitySummary(for wrapped: CafeWrapped, standing: StreakStanding? = nil) -> String {
        switch self {
        case .intro: "Cafe Wrapped for \(wrapped.period.name). \(IntroPage.subtitle(for: wrapped))"
        case .total: Self.totalSummary(wrapped)
        case .cafes: Self.cafesSummary(wrapped)
        case .topItems: Self.topItemsSummary(wrapped)
        // The page's own elements name the item once the foil is off.
        case .favorite: "Your number 1."
        case .times: Self.timesSummary(wrapped)
        case .days: Self.daysSummary(wrapped)
        case .records: Self.recordsSummary(wrapped, standing: standing)
        case .persona: Self.personaSummary(wrapped)
        case .summary: "Your recap poster. Share it or tap Done."
        }
    }

    private static func totalSummary(_ wrapped: CafeWrapped) -> String {
        let purchases = WrappedFormat.count(wrapped.purchaseCount, "cafe purchase")
        let days = WrappedFormat.count(wrapped.dayCount, "day")
        return "You spent \(wrapped.total.usd()) on \(purchases) across \(days), \(wrapped.averagePerDay.usd()) a day on average."
    }

    private static func cafesSummary(_ wrapped: CafeWrapped) -> String {
        let favorite = wrapped.favorite?.id
        let lines: [String] = wrapped.cafes.map { cafe in
            let share = "You spent \(cafe.total.usd()) there, \(WrappedFormat.percent(cafe.share)) of your spending, on \(WrappedFormat.count(cafe.purchaseCount, "purchase"))."
            let items = cafe.topItems.map { item in
                item.id == favorite ? "Your number 1, still hidden." : "\(item.name), \(WrappedFormat.count(item.count, "time"))."
            }
            let mostBought = items.isEmpty ? [] : ["Most bought there."] + items
            return ([cafe.name + ".", share] + mostBought).joined(separator: " ")
        }
        return (["Where you went."] + lines).joined(separator: " ")
    }

    /// Keeps #1 hidden, as the page does, for the favorite page to reveal.
    private static func topItemsSummary(_ wrapped: CafeWrapped) -> String {
        let lines: [String] = wrapped.topItems.enumerated().dropFirst().map { rank, item in
            "Number \(rank + 1) is \(item.name), \(WrappedFormat.count(item.count, "time"))."
        }
        return (["Your top \(wrapped.topItems.count)."] + lines + ["Your number 1 is on the next page."]).joined(separator: " ")
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
            parts.append("\(WrappedFormat.weekday(weekday)) was your busiest day.")
        }
        parts.append(DaysPage.visits(wrapped))
        if wrapped.months.count > 1, let month = wrapped.biggestMonth {
            parts.append("You spent the most in \(WrappedFormat.month(month.month)), \(month.total.usd()).")
        }
        return parts.joined(separator: " ")
    }

    private static func recordsSummary(_ wrapped: CafeWrapped, standing: StreakStanding?) -> String {
        var parts = ["Personal bests."]
        if let streak = wrapped.longestStreak, streak.length > 1 {
            parts.append("\(streak.length) days in a row, \(WrappedFormat.streakDates(streak)).")
            if let standing {
                parts.append("Top \(standing.topPercent)% of Nobles students.")
            }
        }
        if wrapped.distinctItemCount > 1 {
            parts.append("You tried \(wrapped.distinctItemCount) different things.")
        }
        if wrapped.dayCount > 1, let day = wrapped.biggestDay {
            parts.append("Your biggest day was \(WrappedFormat.day(day.date)), with \(day.total.usd()) on \(WrappedFormat.count(day.itemCount, "item")).")
        }
        if let charge = wrapped.biggestPurchase {
            parts.append("Your biggest purchase was \(charge.detail), \(charge.total.usd()), on \(WrappedFormat.moment(charge.madeAt)).")
        }
        if let charge = wrapped.firstPurchase, charge.id != wrapped.biggestPurchase?.id {
            parts.append("Your first purchase was \(charge.detail), on \(WrappedFormat.moment(charge.madeAt)).")
        }
        return parts.joined(separator: " ")
    }

    private static func personaSummary(_ wrapped: CafeWrapped) -> String {
        let persona = "Your cafe personality is \(wrapped.persona.title). \(wrapped.persona.tagline)"
        guard let evidence = PersonaEvidence(wrapped) else { return persona }
        return "\(persona) \(evidence.spoken)."
    }
}
