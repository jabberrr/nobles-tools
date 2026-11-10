import SwiftUI
import WidgetKit
import NoblesKit

/// A spending design rendered at one widget size. The widget and the app's previews both use it.
///
/// Every size leads with the design's highlighted figure (total spent, remaining or the latest
/// charge). The Home Screen follows it with the recent charges that fit, and the large size adds
/// per-store totals. When no account is connected, a friendly prompt replaces the figures.
struct StoreWidgetView: View {
    let design: WidgetDesign
    let family: WidgetFamily
    let colors: ThemeColors
    /// The spending to show, or `nil` when there's nothing (not even a cached copy).
    let statement: StoreStatement?
    /// How current and connected `statement` is.
    let status: StoreStatus
    /// The moment on screen (the timeline entry's date).
    let now: Date

    var body: some View {
        let configuration = design.storeConfiguration ?? StoreConfiguration()
        let content = StoreContent(statement: statement, configuration: configuration, status: status, now: now)
        if family.isAccessory {
            StoreLockScreenView(content: content, family: family, colors: colors, fontDesign: design.theme.font.fontDesign)
        } else {
            StoreHomeScreenView(content: content, family: family, colors: colors, fontDesign: design.theme.font.fontDesign)
        }
    }
}

/// Spending on the Home Screen: the figure large on the small size, with a charges list on the
/// others and per-store totals on the large one.
private struct StoreHomeScreenView: View {
    let content: StoreContent
    let family: WidgetFamily
    let colors: ThemeColors
    let fontDesign: Font.Design

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            header
            switch content.state {
            case .connect:
                WidgetMessage(
                    symbol: "creditcard",
                    title: "Connect your account",
                    detail: "Open Nobles Tools to sign in",
                    colors: colors
                )
            case .unavailable:
                WidgetMessage(symbol: "wifi.slash", title: "Spending unavailable", detail: "Will try again soon", colors: colors)
            case .spending(let spending):
                switch family {
                case .systemSmall: small(spending)
                case .systemMedium: medium(spending)
                default: large(spending)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "Spending", with the store filter beside it on the wider sizes (dropped when it won't fit).
    private var header: some View {
        WidgetHeader(symbol: "creditcard", title: "Spending", detail: family == .systemSmall ? nil : storeSummary, colors: colors)
    }

    private var storeSummary: String? {
        guard case .spending(let spending) = content.state, !spending.stores.isEmpty else { return nil }
        return spending.storeSummary
    }

    // MARK: Figure

    /// The highlighted dollars over their short label.
    private func figure(_ spending: StoreContent.Spending, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(spending.figure.amount)
                .font(.system(size: size, weight: .bold, design: fontDesign))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(spending.figure.caption)
                .font(.footnote.weight(.medium))
                .foregroundStyle(colors.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The highlighted dollars with their label beside them on one line; the label shortens at
    /// words, and the dollars shrink rather than ever being cut.
    private func inlineFigure(_ spending: StoreContent.Spending, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(spending.figure.amount)
                .font(.system(size: size, weight: .bold, design: fontDesign))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(1)
            let caption = spending.figure.caption
            FirstFitting(variants: [caption] + caption.cutsAtWords(limit: 3), axes: .horizontal) { Text($0) }
                .font(.footnote.weight(.medium))
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
        }
    }

    /// The bar against the limit and its caption ("$58 of $300", "$242 left of $300"), when the
    /// design sets a limit.
    @ViewBuilder private func limitBar(_ spending: StoreContent.Spending, height: CGFloat) -> some View {
        if let meter = spending.meter {
            ProgressBar(progress: meter.progress, colors: colors)
                .frame(height: height)
            Text(meter.caption)
                .font(.caption2)
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
        }
    }

    /// "Updated 4h ago" or "Sign in to refresh", quietly, when the data is a cached copy.
    @ViewBuilder private var note: some View {
        if let note = content.note {
            Text(note)
                .font(.caption2)
                .foregroundStyle(colors.secondary)
                .lineLimit(1)
        }
    }

    private func charges(_ spending: StoreContent.Spending, capacity: Int) -> some View {
        FittingList(
            items: spending.charges,
            capacity: capacity,
            spacing: 7,
            overflowColor: colors.secondary,
            hidesOverflowWhenEmpty: true
        ) { charge in
            ChargeRow(charge: charge, today: content.today, colors: colors)
        }
    }

    // MARK: Small

    private func small(_ spending: StoreContent.Spending) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            figure(spending, size: 38)
            limitBar(spending, height: 7)
            note
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium

    /// The figure, then the recent charges across the full width so item names aren't cut; the
    /// figure alone when the list is empty or turned off. With a list, the figure's label sits
    /// beside it, leaving the list room for a row.
    @ViewBuilder private func medium(_ spending: StoreContent.Spending) -> some View {
        if spending.charges.isEmpty {
            figure(spending, size: 46)
        } else {
            inlineFigure(spending, size: 34)
        }
        limitBar(spending, height: 7)
        if !spending.charges.isEmpty {
            charges(spending, capacity: 4)
                .layoutPriority(1)
        }
        Spacer(minLength: 0)
        note
    }

    // MARK: Large

    /// The figure on a card, the per-store totals (there are only a few, so they lead), then the
    /// recent charges filling whatever height is left.
    private func large(_ spending: StoreContent.Spending) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            figureCard(spending)
            if spending.totals.count > 1 {
                Eyebrow(symbol: "building.2", text: "By store", colors: colors)
                VStack(spacing: 6) {
                    ForEach(spending.totals, id: \.storeName) { total in
                        StoreTotalRow(total: total, colors: colors)
                    }
                }
            }
            if !spending.charges.isEmpty {
                recentSection(spending)
            }
            Spacer(minLength: 0)
            note
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The recent charges under a "Recent" header, which disappears whole when no row fits — so the
    /// header never sits alone over a bare "+N more" when the card and per-store totals fill the
    /// large size.
    private func recentSection(_ spending: StoreContent.Spending) -> some View {
        let most = min(spending.charges.count, 5)
        return FirstFitting(variants: Array((0...most).reversed()), axes: .vertical) { count in
            recent(spending, showing: count)
        }
    }

    @ViewBuilder private func recent(_ spending: StoreContent.Spending, showing count: Int) -> some View {
        if count > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(symbol: "clock", text: "Recent", colors: colors)
                VStack(spacing: 7) {
                    ForEach(spending.charges.prefix(count)) { charge in
                        ChargeRow(charge: charge, today: content.today, colors: colors)
                    }
                }
                if count < spending.charges.count {
                    MoreLabel(count: spending.charges.count - count, color: colors.secondary)
                }
            }
        }
    }

    private func figureCard(_ spending: StoreContent.Spending) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            figure(spending, size: 38)
            limitBar(spending, height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
