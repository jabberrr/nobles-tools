import SwiftUI
import WidgetKit

@main
struct NoblesWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MenuWidget()
        CountdownWidget()
        ScoresWidget()
    }
}
