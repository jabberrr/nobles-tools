import Foundation
import Observation
import NoblesKit

/// A preview's data, and where it came from.
enum PreviewContent<Value> {
    case loading
    case fetched(Value)
    /// Bundled sample data, shown because the real data couldn't be loaded.
    case sample(Value)

    var value: Value? {
        switch self {
        case .loading: nil
        case .fetched(let value), .sample(let value): value
        }
    }

    var isSample: Bool {
        if case .sample = self { true } else { false }
    }

    var isFetched: Bool {
        if case .fetched = self { true } else { false }
    }
}

/// Live data behind the app's design previews, shared by the list thumbnails and the editor.
/// Falls back to sample data when a source can't be reached, so previews always render.
@MainActor @Observable
final class PreviewData {
    enum Request: Hashable {
        case menu(MealSelection)
        case scores(ScoresConfiguration)
        case meals
    }

    private(set) var menus: [MealSelection: PreviewContent<UpcomingMenu>] = [:]
    private(set) var scoreboards: [ScoresConfiguration: PreviewContent<Scoreboard>] = [:]
    /// The meals the dining hall publishes: lunch and dinner until the real list loads.
    private(set) var availableMeals: [Meal] = [.lunch, .dinner]

    /// When each request last started; a request is repeated once its data is this old.
    @ObservationIgnored private var started: [Request: Date] = [:]
    private static let lifetime: TimeInterval = 10 * 60

    private let menuService = MenuService()
    private let scoresService = ScoresService.nobles

    /// Scores with every filter off, for listing the sports a design can pick from.
    static let allSports = ScoresConfiguration(sports: [], varsityOnly: false, showsUpcoming: true)

    func menu(for selection: MealSelection) -> PreviewContent<UpcomingMenu> {
        menus[selection] ?? .loading
    }

    func scoreboard(for configuration: ScoresConfiguration) -> PreviewContent<Scoreboard> {
        scoreboards[configuration] ?? .loading
    }

    /// Every sport in the unfiltered scoreboard, alphabetically. Load `.scores(PreviewData.allSports)` first.
    var knownSports: [String] {
        guard let scoreboard = scoreboards[Self.allSports]?.value else { return [] }
        let games = scoreboard.live + scoreboard.recent + scoreboard.upcoming
        return Set(games.map(\.sport)).sorted()
    }

    /// Fetches the data for `request` unless it's already loading or fresh.
    func load(_ request: Request) async {
        guard needsLoad(request) else { return }
        started[request] = .now
        do {
            switch request {
            case .menu(let selection):
                let upcoming = try await menuService.upcomingMenu(for: selection)
                menus[selection] = .fetched(upcoming)
            case .scores(let configuration):
                let scoreboard = try await scoresService.scoreboard(for: configuration)
                scoreboards[configuration] = .fetched(scoreboard)
            case .meals:
                availableMeals = try await menuService.availableMeals()
            }
        } catch {
            // Retry the next time a preview appears; until then keep real data if there is any.
            started[request] = nil
            switch request {
            case .menu(let selection) where menus[selection]?.isFetched != true:
                menus[selection] = .sample(UpcomingMenu.placeholder(for: selection))
            case .scores(let configuration) where scoreboards[configuration]?.isFetched != true:
                scoreboards[configuration] = .sample(Scoreboard.sample)
            default:
                break
            }
        }
    }

    private func needsLoad(_ request: Request) -> Bool {
        if case .menu(let selection) = request, case .fetched(let upcoming)? = menus[selection], upcoming.validUntil < .now {
            return true
        }
        guard let lastStart = started[request] else { return true }
        return Date.now.timeIntervalSince(lastStart) > Self.lifetime
    }
}
