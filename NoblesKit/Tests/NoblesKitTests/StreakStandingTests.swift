import Testing
@testable import NoblesKit

struct StreakStandingTests {
    @Test func longestStreakIsTopOnePercent() throws {
        let standing = try #require(StreakStanding(length: 12, among: Array(repeating: 3, count: 239)))
        #expect(standing == StreakStanding(studentCount: 240, topPercent: 1))
    }

    @Test func tiesCountAsAtLeastAsLong() throws {
        // You, the 5 and the two other 3s: 4 of 10 have 3 days or more.
        let standing = try #require(StreakStanding(length: 3, among: [5, 3, 3, 2, 2, 1, 1, 1, 1]))
        #expect(standing == StreakStanding(studentCount: 10, topPercent: 40))
    }

    @Test func topPercentRoundsUp() throws {
        // 2 of 30 is 6.67%.
        let others = [9] + Array(repeating: 2, count: 28)
        #expect(StreakStanding(length: 4, among: others)?.topPercent == 7)
    }

    @Test func topHalfIsShownAndBelowItIsNot() {
        // 5 of 10 at 6 days or more is the top 50%; 6 of 10 at 5 days or more isn't shown.
        #expect(StreakStanding(length: 6, among: [9, 8, 7, 6, 5, 4, 3, 2, 1])?.topPercent == 50)
        #expect(StreakStanding(length: 5, among: [9, 8, 7, 6, 5, 4, 3, 2, 1]) == nil)
    }

    @Test func needsTenStudents() {
        #expect(StreakStanding(length: 6, among: Array(repeating: 2, count: 8)) == nil)
        #expect(StreakStanding(length: 6, among: Array(repeating: 2, count: 9))?.studentCount == 10)
    }

    @Test func needsAStreakOfTwoDays() {
        let others = Array(repeating: 1, count: 20)
        #expect(StreakStanding(length: 1, among: others) == nil)
        #expect(StreakStanding(length: 2, among: others)?.topPercent == 5)
    }

    @Test func junkLengthsAreLeftOut() throws {
        // Only the nine plausible lengths count, so the 500 doesn't beat you.
        let others = [0, -4, 500, 201] + Array(repeating: 3, count: 9)
        let standing = try #require(StreakStanding(length: 7, among: others))
        #expect(standing == StreakStanding(studentCount: 10, topPercent: 10))
        // The extremes of the plausible range count.
        #expect(StreakStanding(length: 7, among: [1, 200] + Array(repeating: 3, count: 7))?.topPercent == 20)
    }

    @Test func sampleIsShowable() {
        #expect(StreakStanding.sample.studentCount >= StreakStanding.minimumStudentCount)
        #expect((1...50).contains(StreakStanding.sample.topPercent))
    }
}
