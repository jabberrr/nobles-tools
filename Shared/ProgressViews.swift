import SwiftUI
import WidgetKit

/// A circular progress track, filled clockwise from the top.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    let colors: ThemeColors

    var body: some View {
        ZStack {
            Circle()
                .stroke(colors.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(colors.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .padding(lineWidth / 2)
    }
}

/// A horizontal capsule progress bar.
struct ProgressBar: View {
    let progress: Double
    let colors: ThemeColors

    var body: some View {
        GeometryReader { proxy in
            let filled = progress > 0 ? max(proxy.size.height, proxy.size.width * CGFloat(progress)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(colors.track)
                Capsule().fill(colors.accent)
                    .frame(width: filled)
                    .widgetAccentable()
            }
        }
    }
}
