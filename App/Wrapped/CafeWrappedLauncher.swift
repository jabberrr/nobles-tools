import SwiftUI
import NoblesKit

/// Opens Cafe Wrapped full screen: the sample at once, or the connected account's own semester once
/// its purchases load, with a friendly message (and the sample on offer) when there's no recap.
struct CafeWrappedLauncher: View {
    /// Whose purchases to recap.
    enum Source: String, Identifiable {
        /// The connected Nobles account's.
        case account
        /// Made-up purchases, to try it out.
        case sample

        var id: String { rawValue }
    }

    let source: Source

    @Environment(PreviewData.self) private var previewData
    @Environment(DesignLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    /// Whether the saved account has been read again since opening. Until then the one
    /// `previewData` knows may be out of date: Settings may have just connected it.
    @State private var hasCheckedAccount = false
    /// Set by "See a Sample".
    @State private var showsSample = false

    private enum Phase {
        case recap(CafeWrapped)
        case loading
        case message(WrappedMessage)
    }

    var body: some View {
        // A ZStack rather than a Group, so the task runs once rather than for each phase's view.
        ZStack {
            switch phase {
            case .recap(let wrapped):
                CafeWrappedView(wrapped: wrapped)
            case .loading:
                WrappedLoadingView { dismiss() }
            case .message(let message):
                WrappedMessageView(message: message, onSample: { showSample() }, onClose: { dismiss() })
            }
        }
        .task { await loadAccount() }
    }

    private var phase: Phase {
        if source == .sample || showsSample {
            return .recap(.sample)
        }
        guard hasCheckedAccount else { return .loading }
        guard previewData.isStoreConnected else { return .message(.notConnected) }
        guard case .fetched(let statement) = previewData.spending else {
            // With an account connected, the sample stands in only when nothing could be loaded.
            return previewData.spending.isSample ? .message(.unavailable) : .loading
        }
        let today = LocalDate.today()
        guard let semester = CafeWrapped.semester(in: library.calendar, on: today) else {
            return .message(.noSemester)
        }
        guard let wrapped = CafeWrapped(statement: statement, semester: semester, calendar: library.calendar, asOf: today) else {
            return .message(.noPurchases(in: CafeWrapped.periodName(for: semester.span)))
        }
        return .recap(wrapped)
    }

    /// Picks up the account as Settings left it, then loads its purchases (its cached copy when
    /// offline). `previewData` publishes the result, which `phase` follows.
    private func loadAccount() async {
        guard source == .account else { return }
        previewData.refreshStoreSession()
        hasCheckedAccount = true
        guard previewData.isStoreConnected else { return }
        await previewData.load(.spending(previewData.storeSession))
    }

    private func showSample() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showsSample = true
        }
    }
}
