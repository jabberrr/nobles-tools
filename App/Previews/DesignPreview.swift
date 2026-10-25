import SwiftUI
import WidgetKit
import NoblesKit

/// A live preview of a design at one size, drawn by the same views the widget uses.
///
/// Menus and scores load real data through `PreviewData`; until it arrives the preview shows
/// redacted sample content, like a widget placeholder.
struct DesignPreview: View {
    let design: WidgetDesign
    let family: WidgetFamily

    @Environment(PreviewData.self) private var data
    @Environment(DesignLibrary.self) private var library

    var body: some View {
        WidgetPreviewFrame(family: family, theme: design.theme) {
            content
        }
        .task(id: request) {
            if let request {
                await data.load(request)
            }
        }
    }

    /// What needs fetching for this design, if anything.
    private var request: PreviewData.Request? {
        switch design.content {
        case .menu(let configuration): .menu(configuration.meal)
        case .scores(let configuration): .scores(configuration)
        case .countdown: nil
        }
    }

    @ViewBuilder private var content: some View {
        switch design.content {
        case .menu(let configuration):
            let menu = data.menu(for: configuration.meal)
            MenuWidgetView(
                design: design,
                family: family,
                upcoming: menu.value ?? UpcomingMenu.placeholder(for: configuration.meal),
                now: .now
            )
            .redacted(reason: menu.value == nil ? .placeholder : [])
        case .countdown(let configuration):
            CountdownWidgetView(
                design: design,
                family: family,
                snapshot: CountdownSnapshot(configuration: configuration, calendar: library.calendar, date: .today())
            )
        case .scores(let configuration):
            let scoreboard = data.scoreboard(for: configuration)
            ScoresWidgetView(
                design: design,
                family: family,
                scoreboard: scoreboard.value ?? Scoreboard.sample,
                now: .now
            )
            .redacted(reason: scoreboard.value == nil ? .placeholder : [])
        }
    }
}

extension PreviewData {
    /// Whether `design`'s previews are showing sample data because the real data couldn't load.
    func isShowingSample(for design: WidgetDesign) -> Bool {
        switch design.content {
        case .menu(let configuration): menu(for: configuration.meal).isSample
        case .scores(let configuration): scoreboard(for: configuration).isSample
        case .countdown: false
        }
    }
}
