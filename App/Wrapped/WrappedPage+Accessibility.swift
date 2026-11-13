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
        var parts: [String]
        if let cafe = wrapped.cafes.first, wrapped.cafes.count == 1 {
            parts = [
                "Your cafe was \(cafe.name).",
                "You spent \(cafe.total.usd()) there on \(WrappedFormat.count(cafe.purchaseCount, "purchase")).",
            ]
        } else {
            parts = ["Where you went."] + wrapped.cafes.map { cafe in
                "\(cafe.name), \(WrappedFormat.percent(cafe.share)) of your spending, \(cafe.total.usd())."
            }
            parts += favoredWeekdays(wrapped).map { cafe, weekdays in
                "Most spent at \(cafe) on \(weekdays.map(WrappedFormat.weekday).formatted(.list(type: .and)))."
            }
        }
        if let week = CafeBreakdown(wrapped).biggestWeek {
            parts.append("Your biggest week started \(WrappedFormat.day(week.start)), with \(week.total.usd()).")
        }
        return parts.joined(separator: " ")
    }

    /// Each cafe that got the most on some weekday, in the recap's order, with those weekdays
    /// from Monday on: what the page's weekday chart shows.
    private static func favoredWeekdays(_ wrapped: CafeWrapped) -> [(cafe: String, weekdays: [Int])] {
        var weekdays: [String: [Int]] = [:]
        for weekday in [2, 3, 4, 5, 6, 7, 1] {
            let spent = { (cafe: CafeWrapped.Cafe) in cafe.weekdayTotals[weekday - 1] }
            if let top = wrapped.cafes.max(by: { spent($0) < spent($1) }), spent(top) > 0 {
                weekdays[top.id, default: []].append(weekday)
            }
        }
        return wrapped.cafes.compactMap { cafe in weekdays[cafe.id].map { (cafe: cafe.name, weekdays: $0) } }
    }

    /// Keeps #1 hidden, as the page does, for the favorite page to reveal.
    private static func topItemsSummary(_ wrapped: CafeWrapped) -> String {
        let lines: [String] = wrapped.topItems.enumerated().dropFirst().map { rank, item in
            "Number \(rank + 1), \(item.name), \(WrappedFormat.count(item.count, "time")), \(item.total.usd()) in all."
        }
        return (["Most ordered. Your top \(wrapped.topItems.count).", "Number 1 is still under foil."] + lines).joined(separator: " ")
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
        let persona = "Your cafe personality is \(wrapped.persona.title). \(wrapped.persona.tagline)."
        guard let evidence = PersonaEvidence(wrapped) else { return persona }
        return "\(persona) \(evidence.spoken)."
    }
}
