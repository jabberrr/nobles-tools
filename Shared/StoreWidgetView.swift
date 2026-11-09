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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// The spent-against-limit bar and its caption, when the design sets a limit.
    @ViewBuilder private func limitBar(_ spending: StoreContent.Spending, height: CGFloat) -> some View {
        if let progress = spending.progress {
            ProgressBar(progress: progress, colors: colors)
                .frame(height: height)
            if let caption = spending.limitCaption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(colors.secondary)
                    .lineLimit(1)
            }
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
        FittingList(items: spending.charges, capacity: capacity, spacing: 7, overflowColor: colors.secondary) { charge in
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

    /// The figure on the left, the recent charges on the right; or the figure alone when the list
    /// is empty or turned off.
    @ViewBuilder private func medium(_ spending: StoreContent.Spending) -> some View {
        if spending.charges.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                figure(spending, size: 46)
                limitBar(spending, height: 7)
                Spacer(minLength: 0)
                note
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    figure(spending, size: 34)
                    limitBar(spending, height: 6)
                    Spacer(minLength: 0)
                    note
                }
                .frame(width: 130, alignment: .topLeading)
                Rectangle()
                    .fill(colors.track)
                    .frame(width: 1)
                charges(spending, capacity: 4)
            }
        }
    }

    // MARK: Large

    /// The figure on a card, the recent charges, then per-store totals when more than one store.
    private func large(_ spending: StoreContent.Spending) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            figureCard(spending)
            if !spending.charges.isEmpty {
                Eyebrow(symbol: "clock", text: "Recent", colors: colors)
                charges(spending, capacity: 5)
                    .layoutPriority(1)
            }
            if spending.totals.count > 1 {
                Eyebrow(symbol: "building.2", text: "By store", colors: colors)
                FittingList(items: spending.totals, capacity: 4, spacing: 6, overflowColor: colors.secondary) { total in
                    StoreTotalRow(total: total, colors: colors)
                }
            }
            Spacer(minLength: 0)
            note
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func figureCard(_ spending: StoreContent.Spending) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            figure(spending, size: 44)
            limitBar(spending, height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(colors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
