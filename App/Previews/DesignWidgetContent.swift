import SwiftUI
import WidgetKit
import NoblesKit

/// A design's widget content drawn from given data. The editor's live previews and the rendered
/// widget gallery both use it, so each shows exactly what the widget would.
struct DesignWidgetContent: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The menu a menu design shows; `nil` shows it as unavailable.
    let menu: UpcomingMenu?
    /// The games a scores design shows; `nil` shows them as unavailable.
    let scoreboard: Scoreboard?
    /// The spending a spending design shows; `nil` shows a connect prompt or an unavailable state.
    let statement: StoreStatement?
    /// How current and connected `statement` is.
    let storeStatus: StoreStatus
    /// The school calendar a countdown design counts against.
    let calendar: SchoolCalendar
    let now: Date

    var body: some View {
        switch design.content {
        case .menu:
            MenuWidgetView(design: design, family: family, colors: colors, upcoming: menu, now: now)
        case .countdown(let configuration):
            CountdownWidgetView(
                design: design,
                family: family,
                colors: colors,
                snapshot: CountdownSnapshot(configuration: configuration, calendar: calendar, date: LocalDate(now))
            )
        case .scores:
            ScoresWidgetView(design: design, family: family, colors: colors, scoreboard: scoreboard, now: now)
        case .spending:
            StoreWidgetView(design: design, family: family, colors: colors, statement: statement, status: storeStatus, now: now)
        }
    }
}
