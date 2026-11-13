import Foundation

/// Where a cafe streak stands among other students' for the same semester.
public struct StreakStanding: Hashable, Sendable {
    /// Students compared, you included.
    public var studentCount: Int
    /// "Top X%", as a whole percent, 1...50 (a standing past the top half isn't shown).
    public var topPercent: Int

    public init(studentCount: Int, topPercent: Int) {
        self.studentCount = studentCount
        self.topPercent = topPercent
    }
}

extension StreakStanding {
    /// Fewest students, you included, for a standing to mean anything.
    public static let minimumStudentCount = 10
    /// Others' lengths outside this range are junk (anyone can write to the shared list) and left out.
    public static let plausibleLengths = 1...200

    /// A standing for the sample recap and the gallery.
    public static let sample = StreakStanding(studentCount: 240, topPercent: 12)

    /// Where a streak of `length` stands among `others`' longest streaks that semester.
    ///
    /// Your rank is one more than the number of others with a strictly longer streak, so ties share
    /// the better rank, and `topPercent` rounds the rank's share of everyone up. `nil` when it
    /// shouldn't show: fewer than `minimumStudentCount` students in all, a streak under 2 days, or a
    /// standing outside the top half.
    public init?(length: Int, among others: [Int]) {
        let others = others.filter(Self.plausibleLengths.contains)
        let studentCount = others.count + 1
        guard length >= 2, studentCount >= Self.minimumStudentCount else { return nil }
        let rank = 1 + others.count(where: { $0 > length })
        let topPercent = (100 * rank + studentCount - 1) / studentCount
        guard topPercent <= 50 else { return nil }
        self.init(studentCount: studentCount, topPercent: topPercent)
    }
}
