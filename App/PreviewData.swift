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
///
/// Each source is fetched once, and again once it's stale. Designs filter the shared copy
/// themselves, so changing a design's settings redraws its previews at once, without a fetch or
/// a loading state. When a source can't be reached, previews fall back to sample data so they
/// always render.
@MainActor @Observable
final class PreviewData {
    enum Request: Hashable {
        /// The upcoming menu for one meal selection, which every design for it filters.
        case menu(MealSelection)
        /// The games every scores design filters.
        case scores
        /// The meals the dining hall publishes.
        case meals
    }

    private(set) var menus: [MealSelection: PreviewContent<UpcomingMenu>] = [:]
    private(set) var feed: PreviewContent<GameFeed> = .loading
    /// The meals the dining hall publishes: lunch and dinner until the real list loads.
    private(set) var availableMeals: [Meal] = [.lunch, .dinner]

    /// When each request last started; a request is repeated once its data is this old.
    @ObservationIgnored private var started: [Request: Date] = [:]
    private static let lifetime: TimeInterval = 10 * 60

    private let menuService = MenuService()
    private let scoresService = ScoresService.nobles

    /// The sample scoreboard's games, shown while the feed loads or when it can't be reached.
    static var sampleFeed: GameFeed {
        let sample = Scoreboard.sample
        return GameFeed(games: sample.live + sample.recent + sample.upcoming, fetchedAt: .now)
    }

    func menu(for selection: MealSelection) -> PreviewContent<UpcomingMenu> {
        menus[selection] ?? .loading
    }

    /// Whether `design`'s previews are showing sample data because the real data couldn't load.
    func isShowingSample(for design: WidgetDesign) -> Bool {
        switch design.content {
        case .menu(let configuration): menu(for: configuration.meal).isSample
        case .scores: feed.isSample
        case .countdown: false
        }
    }

    /// Fetches the data for `request` unless it's already loading or fresh. A failed fetch keeps
    /// any real data already loaded, or else shows sample data, and is retried the next time a
    /// preview asks.
    func load(_ request: Request) async {
        guard needsLoad(request) else { return }
        started[request] = .now
        switch request {
        case .menu(let selection):
            do {
                let upcoming = try await menuService.upcomingMenu(for: selection)
                menus[selection] = .fetched(upcoming)
            } catch {
                started[request] = nil
                if menus[selection]?.isFetched != true {
                    menus[selection] = .sample(UpcomingMenu.placeholder(for: selection))
                }
            }
        case .scores:
            do {
                let games = try await scoresService.feed()
                feed = .fetched(games)
            } catch {
                started[request] = nil
                if !feed.isFetched {
                    feed = .sample(Self.sampleFeed)
                }
            }
        case .meals:
            availableMeals = await menuService.availableMeals()
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
