import SwiftUI
import NoblesKit

/// Shares the connected account's longest cafe streak this semester on `StreakBoard` while the app
/// is active, so the pool of streaks is already full when anyone opens their recap.
///
/// It loads the account's statement at launch, on each return to the foreground and once Settings
/// connects an account, then shares the streak from each statement that arrives, whoever loaded
/// it. A streak just like the last one shared waits for the next day. Silent: it shows nothing,
/// blocks nothing and swallows every error.
struct StreakSync: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PreviewData.self) private var previewData
    @Environment(DesignLibrary.self) private var library

    func body(content: Content) -> some View {
        content
            .task(id: accountToLoad) {
                // A no-op while the statement is fresh or already loading.
                guard let session = accountToLoad else { return }
                await previewData.load(.spending(session))
            }
            .task(id: statementToShare?.fetchedAt) {
                guard let statement = statementToShare else { return }
                await share(from: statement)
            }
    }

    /// The connected account, while the app is active.
    private var accountToLoad: StoreSession? {
        scenePhase == .active ? previewData.storeSession : nil
    }

    /// The account's statement while the app is active, fresh or its cached copy, never the sample.
    private var statementToShare: StoreStatement? {
        guard scenePhase == .active, case .fetched(let statement) = previewData.spending else { return nil }
        return statement
    }

    /// Shares the longest streak in `statement` for the semester a recap would open on today.
    private func share(from statement: StoreStatement) async {
        let calendar = library.calendar
        let today = LocalDate.today()
        guard let semester = CafeWrapped.semester(in: calendar, on: today),
              let recap = CafeWrapped(statement: statement, semester: semester, calendar: calendar, asOf: today),
              let length = recap.longestStreak?.length
        else { return }
        let streak = SharedStreak(semester: recap.period.name, length: length, day: today)
        guard streak != SharedStreak.last, await StreakBoard.share(length, in: streak.semester) else { return }
        streak.remember()
    }
}

/// The streak this device last shared, kept in the app's standard defaults (not the app group's).
private struct SharedStreak: Codable, Equatable {
    var semester: String
    var length: Int
    var day: LocalDate

    private static let key = "cafeStreak.lastShared.v1"

    static var last: Self? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }

    func remember() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
