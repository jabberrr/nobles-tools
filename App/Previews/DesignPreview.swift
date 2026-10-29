import SwiftUI
import WidgetKit
import NoblesKit

/// A live preview of a design at one size, drawn by the same views the widget uses.
///
/// Menus and scores come from data `PreviewData` shares between designs, and each design's
/// filters apply as it draws, so editing a setting redraws at once. Until the data first arrives
/// the preview shows redacted sample content, like a widget placeholder.
struct DesignPreview: View {
    let design: WidgetDesign
    let family: WidgetFamily

    @Environment(PreviewData.self) private var data
    @Environment(DesignLibrary.self) private var library

    var body: some View {
        let now = Date.now
        WidgetPreviewFrame(family: family, theme: design.theme) { colors in
            DesignWidgetContent(
                design: design,
                family: family,
                colors: colors,
                menu: menu.value ?? UpcomingMenu.placeholder(for: mealSelection, now: now),
                scoreboard: scoreboard(now: now),
                calendar: library.calendar,
                now: now
            )
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .task(id: request) {
            if let request {
                await data.load(request)
            }
        }
    }

    /// What needs fetching for this design, if anything. It doesn't depend on the design's
    /// filters, so changing them never fetches again.
    private var request: PreviewData.Request? {
        switch design.content {
        case .menu(let configuration): .menu(configuration.meal)
        case .scores: .scores
        case .countdown: nil
        }
    }

    private var mealSelection: MealSelection { design.menuConfiguration?.meal ?? .lunch }

    private var menu: PreviewContent<UpcomingMenu> { data.menu(for: mealSelection) }

    /// Whether the design's data is still loading, so the preview shows a redacted placeholder.
    private var isLoading: Bool {
        switch design.content {
        case .menu: menu.value == nil
        case .scores: data.feed.value == nil
        case .countdown: false
        }
    }

    /// The design's games once real ones load. Until then, or when they can't load, the sample
    /// scoreboard unfiltered, so a sample preview is never empty because of the design's filters.
    private func scoreboard(now: Date) -> Scoreboard {
        guard case .fetched(let feed) = data.feed, let configuration = design.scoresConfiguration else { return .sample }
        return Scoreboard(feed: feed, configuration: configuration, now: now)
    }
}
