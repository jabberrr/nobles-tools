import SwiftUI
import NoblesKit

/// Spending adding up over the semester: a line that draws itself in from left to right, the area
/// under it fading in, then a dot popping up at its end with the total. The x-axis runs across
/// the days given and marks where each month starts. Drawn complete in static mode; under Reduce
/// Motion it fades in whole.
struct WrappedLineChart: View {
    /// The running total over the days, in unit coordinates: x from the first day (0) to the last
    /// (1), y from zero (0) to the highest the total reached (1).
    private let points: [CGPoint]
    private let months: [MonthTick]
    private let totalLabel: String
    private let isActive: Bool
    private let height: CGFloat
    private let delay: Double

    @Environment(\.wrappedIsStatic) private var isStatic
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrawn = false
    @State private var showsArea = false
    @State private var showsEnd = false

    private static let drawDuration = 1.6
    /// Room above the line for the total over its end.
    private static let labelRoom: CGFloat = 32
    /// The end dot's radius; the line stops short of the right edge by this much, so the dot fits.
    private static let dotRadius: CGFloat = 7
    /// The narrowest gap after a month's tick that still gets its name.
    private static let monthLabelWidth: CGFloat = 30

    /// One month's start on the x-axis.
    private struct MonthTick: Identifiable {
        let id: Int
        /// 0...1 across the axis; the first month starts at 0 even if `span` starts later.
        let x: CGFloat
        let name: String
    }

    /// - Parameters:
    ///   - days: Each purchase day's spending, in order (`CafeWrapped.days`).
    ///   - span: The days the x-axis covers: the semester's start through the recap's last day.
    ///   - height: The plot's height, the total over its end included; the month names go under.
    ///   - delay: When the line starts drawing once `isActive`.
    init(days: [CafeWrapped.Day], across span: DateSpan, isActive: Bool, height: CGFloat = 140, delay: Double = 0) {
        var running: Decimal = 0
        var totals = [CGPoint(x: 0, y: 0)]
        for day in days where span.contains(day.date) {
            // Flat until the day before, then up over the day: weekends and gaps read as flat.
            let dayBefore = Self.fraction(of: day.date.adding(days: -1), in: span)
            if let last = totals.last, dayBefore > last.x {
                totals.append(CGPoint(x: dayBefore, y: last.y))
            }
            running += day.total
            totals.append(CGPoint(x: Self.fraction(of: day.date, in: span), y: CGFloat(WrappedFormat.double(running))))
        }
        totals.append(CGPoint(x: 1, y: CGFloat(WrappedFormat.double(running))))
        let peak = totals.map(\.y).max() ?? 0
        points = totals.map { CGPoint(x: $0.x, y: peak > 0 ? max($0.y, 0) / peak : 0) }
        months = Self.monthTicks(across: span)
        totalLabel = running.usd()
        self.isActive = isActive
        self.height = height
        self.delay = delay
    }

    var body: some View {
        VStack(spacing: 0) {
            plot
                .frame(height: height)
            axis
                .frame(height: 24)
        }
        .opacity(reduceMotion && !isFinished ? 0 : 1)
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                play()
            } else {
                reset()
            }
        }
        .accessibilityHidden(true)
    }

    private var isFinished: Bool { isStatic || isDrawn }

    // MARK: Drawing

    private var plot: some View {
        GeometryReader { proxy in
            let frame = CGRect(
                x: 0,
                y: Self.labelRoom,
                width: max(proxy.size.width - Self.dotRadius, 0),
                height: max(proxy.size.height - Self.labelRoom - 2, 0)
            )
            let end = Self.location(of: points.last ?? .zero, in: frame)
            ZStack(alignment: .topLeading) {
                Self.areaPath(points, in: frame)
                    .fill(
                        LinearGradient(
                            colors: [WrappedStyle.highlight.opacity(0.4), WrappedStyle.highlight.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isStatic || showsArea ? 1 : 0)
                Self.linePath(points, in: frame)
                    .trim(from: 0, to: isFinished || reduceMotion ? 1 : 0)
                    .stroke(WrappedStyle.highlight, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                endMarker(at: end)
            }
        }
    }

    /// The dot at the line's end and the total over it, right-aligned with the dot.
    private func endMarker(at point: CGPoint) -> some View {
        let isShown = isStatic || showsEnd
        let labelWidth = point.x + Self.dotRadius
        return ZStack(alignment: .topLeading) {
            Circle()
                .fill(WrappedStyle.highlight)
                .overlay { Circle().strokeBorder(Color.white, lineWidth: 3) }
                .frame(width: Self.dotRadius * 2, height: Self.dotRadius * 2)
                .scaleEffect(isShown ? 1 : 0.01)
                .position(point)
            Text(totalLabel)
                .font(WrappedStyle.number(16))
                .monospacedDigit()
                .foregroundStyle(WrappedStyle.highlight)
                .fixedSize()
                .scaleEffect(isShown ? 1 : 0.01, anchor: .bottomTrailing)
                .opacity(isShown ? 1 : 0)
                .frame(width: labelWidth, alignment: .trailing)
                .position(x: labelWidth / 2, y: point.y - 21)
        }
    }

    /// A baseline with a tick where each month starts, named when there's room before the next.
    private var axis: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width - Self.dotRadius, 0)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: width, height: 1)
                ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1, height: 6)
                        .offset(x: month.x * width)
                    if hasRoomForName(at: index, width: width) {
                        Text(month.name)
                            .font(WrappedStyle.chartLabel)
                            .foregroundStyle(WrappedStyle.secondary)
                            .fixedSize()
                            .offset(x: month.x * width + 4, y: 6)
                    }
                }
            }
        }
    }

    private func hasRoomForName(at index: Int, width: CGFloat) -> Bool {
        let next = index + 1 < months.count ? months[index + 1].x : 1
        return (next - months[index].x) * width >= Self.monthLabelWidth
    }

    // MARK: Motion

    private func play() {
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.4).delay(delay)) {
                isDrawn = true
                showsArea = true
                showsEnd = true
            }
            return
        }
        withAnimation(.easeInOut(duration: Self.drawDuration).delay(delay)) { isDrawn = true }
        withAnimation(.easeOut(duration: 0.8).delay(delay + Self.drawDuration * 0.5)) { showsArea = true }
        withAnimation(.spring(duration: 0.5, bounce: 0.5).delay(delay + Self.drawDuration)) { showsEnd = true }
    }

    /// Hides it again at once, so a revisit replays it.
    private func reset() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isDrawn = false
            showsArea = false
            showsEnd = false
        }
    }

    // MARK: Geometry

    /// Where `date` falls across `span`, 0...1.
    private static func fraction(of date: LocalDate, in span: DateSpan) -> CGFloat {
        let length = max(span.start.days(until: span.end), 1)
        return min(max(CGFloat(span.start.days(until: date)) / CGFloat(length), 0), 1)
    }

    /// A tick for each month `span` touches, from its first month on.
    private static func monthTicks(across span: DateSpan) -> [MonthTick] {
        var ticks: [MonthTick] = []
        var year = span.start.year
        var month = span.start.month
        while LocalDate(year: year, month: month, day: 1) <= span.end {
            let first = LocalDate(year: year, month: month, day: 1)
            ticks.append(MonthTick(id: year * 12 + month, x: fraction(of: first, in: span), name: WrappedFormat.shortMonth(month)))
            if month == 12 {
                year += 1
                month = 1
            } else {
                month += 1
            }
        }
        return ticks
    }

    /// A unit point placed in `frame`, y up.
    private static func location(of point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.minX + point.x * frame.width, y: frame.maxY - point.y * frame.height)
    }

    private static func linePath(_ points: [CGPoint], in frame: CGRect) -> Path {
        Path { path in
            path.addLines(points.map { location(of: $0, in: frame) })
        }
    }

    /// The line closed down to the baseline.
    private static func areaPath(_ points: [CGPoint], in frame: CGRect) -> Path {
        Path { path in
            path.addLines(points.map { location(of: $0, in: frame) })
            if let first = points.first, let last = points.last {
                path.addLine(to: location(of: CGPoint(x: last.x, y: 0), in: frame))
                path.addLine(to: location(of: CGPoint(x: first.x, y: 0), in: frame))
            }
            path.closeSubpath()
        }
    }
}

#Preview {
    let wrapped = CafeWrapped.sample
    WrappedLineChart(
        days: wrapped.days,
        across: DateSpan(start: wrapped.period.span.start, end: wrapped.period.through),
        isActive: true,
        delay: 0.5
    )
    .padding(24)
    .background(Color(hex: 0x065F46))
}
