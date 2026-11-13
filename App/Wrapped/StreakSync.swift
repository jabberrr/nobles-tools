import SwiftUI
import NoblesKit

/// Keeps the connected account's longest cafe streak on `StreakBoard` while the app is active, so
/// the pool of streaks is already full when anyone opens their recap.
///
/// While Compare My Streak is on and a semester is under way (or its recap is ready), it loads the
/// account's statement at launch, on each return to the foreground and once Settings connects an
/// account, then shares the streak from each statement that arrives, whoever loaded it. With the
/// setting off, or no account connected, it takes the streak off the board. `StreakSharing` keeps
/// either from going more than once a day. Silent: it shows nothing, blocks nothing and swallows
/// every error.
struct StreakSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PreviewData.self) private var previewData
    @Environment(DesignLibrary.self) private var library
    @AppStorage(StreakSharing.isOnKey) private var isSharing = true

    func body(content: Content) -> some View {
        content
            .task(id: accountToLoad) {
                // A no-op while the statement is fresh or already loading.
                guard let session = accountToLoad else { return }
                await previewData.load(.spending(session))
            }
            .task(id: statementToShare?.fetchedAt) {
                guard let statement = statementToShare, let semester = semesterToShare else { return }
                await share(from: statement, in: semester)
            }
            .task(id: shouldWithdraw) {
                guard shouldWithdraw else { return }
                await StreakSharing.withdraw()
            }
    }

    /// Whether the app is active with sharing on.
    private var isActiveAndSharing: Bool {
        scenePhase == .active && isSharing
    }

    /// The connected account, while sharing in a semester worth sharing.
    private var accountToLoad: StoreSession? {
        guard isActiveAndSharing, semesterToShare != nil else { return nil }
        return previewData.storeSession
    }

    /// The account's statement while sharing, fresh or its cached copy, never the sample.
    private var statementToShare: StoreStatement? {
        guard isActiveAndSharing, case .fetched(let statement) = previewData.spending else { return nil }
        return statement
    }

    /// Whether the streak should come off the board: sharing turned off, or no account connected.
    private var shouldWithdraw: Bool {
        scenePhase == .active && (!isSharing || previewData.storeSession == nil)
    }

    /// The semester a recap would open on today, while it's under way or its recap is ready;
    /// `nil` between school years.
    private var semesterToShare: Term? {
        let today = LocalDate.today()
        guard let semester = CafeWrapped.semester(in: library.calendar, on: today),
              semester.span.contains(today) || CafeWrapped.isReady(semester, on: today)
        else { return nil }
        return semester
    }

    /// Shares the longest streak in `statement` during `semester`.
    private func share(from statement: StoreStatement, in semester: Term) async {
        guard let recap = CafeWrapped(statement: statement, semester: semester, calendar: library.calendar, asOf: .today()),
              let length = recap.longestStreak?.length
        else { return }
        await StreakSharing.share(length, in: recap.period.name)
    }
}
