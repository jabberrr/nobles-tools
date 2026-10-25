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
        WidgetPreviewFrame(family: family, theme: design.theme) { colors in
            content(colors: colors)
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

    /// The design's games once real ones load. Until then, or when they can't load, the sample
    /// scoreboard unfiltered, so a sample preview is never empty because of the design's filters.
    private func scoreboard(for configuration: ScoresConfiguration, now: Date) -> Scoreboard {
        guard case .fetched(let feed) = data.feed else { return .sample }
        return Scoreboard(feed: feed, configuration: configuration, now: now)
    }

    @ViewBuilder private func content(colors: ThemeColors) -> some View {
        let now = Date.now
        switch design.content {
        case .menu(let configuration):
            let menu = data.menu(for: configuration.meal)
            MenuWidgetView(
                design: design,
                family: family,
                colors: colors,
                upcoming: menu.value ?? UpcomingMenu.placeholder(for: configuration.meal, now: now),
                now: now
            )
            .redacted(reason: menu.value == nil ? .placeholder : [])
        case .countdown(let configuration):
            CountdownWidgetView(
                design: design,
                family: family,
                colors: colors,
                snapshot: CountdownSnapshot(configuration: configuration, calendar: library.calendar, date: LocalDate(now))
            )
        case .scores(let configuration):
            ScoresWidgetView(
                design: design,
                family: family,
                colors: colors,
                scoreboard: scoreboard(for: configuration, now: now),
                now: now
            )
            .redacted(reason: data.feed.value == nil ? .placeholder : [])
        }
    }
}
