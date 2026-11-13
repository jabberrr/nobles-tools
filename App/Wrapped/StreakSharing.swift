import Foundation
import NoblesKit

/// Whether this device puts its cafe streak on `StreakBoard`, and the last change it sent there.
///
/// Compare My Streak in Settings turns sharing on and off, and it's on until turned off. Each change
/// (a streak shared, or taken off) is remembered with its day before it's sent, so the same change
/// goes at most once a day whether or not it got through: without an iCloud account, or before the
/// schema is deployed, it isn't retried on every launch.
enum StreakSharing {
    /// The `UserDefaults` key of Compare My Streak, for `@AppStorage`.
    static let isOnKey = "cafeStreak.isSharing"

    /// Puts a streak of `length` days in `semester` (the recap's period name) on the board, unless
    /// that was already sent today.
    static func share(_ length: Int, in semester: String) async {
        let change = BoardChange(semester: semester, length: length, day: .today())
        guard change != BoardChange.last else { return }
        change.remember()
        await StreakBoard.share(length, in: semester)
    }

    /// Takes the streak last shared off the board, then forgets it. Until that gets through, it's
    /// tried again at most once a day.
    static func withdraw() async {
        guard let last = BoardChange.last else { return }
        let change = BoardChange(semester: last.semester, length: nil, day: .today())
        guard change != last else { return }
        change.remember()
        if await StreakBoard.withdraw(from: last.semester) {
            BoardChange.forget()
        }
    }
}

/// A change sent to the board: a streak shared, or one taken off (no length). Kept in the app's
/// standard defaults, on this device only.
private struct BoardChange: Codable, Equatable {
    var semester: String
    var length: Int?
    var day: LocalDate

    private static let key = "cafeStreak.lastChange.v1"

    static var last: Self? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) }
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func remember() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
