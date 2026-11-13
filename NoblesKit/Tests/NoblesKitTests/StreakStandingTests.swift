import Testing
@testable import NoblesKit

struct StreakStandingTests {
    @Test func longestStreakIsTopOnePercent() throws {
        let standing = try #require(StreakStanding(length: 12, among: Array(repeating: 3, count: 239)))
        #expect(standing == StreakStanding(studentCount: 240, topPercent: 1))
    }

    @Test func rankCountsOnlyLongerStreaks() throws {
        // Two longer, three tied: rank 3 of 10.
        let standing = try #require(StreakStanding(length: 5, among: [8, 6, 5, 5, 5, 4, 3, 2, 1]))
        #expect(standing == StreakStanding(studentCount: 10, topPercent: 30))
    }

    @Test func topPercentRoundsUp() throws {
        // Rank 2 of 30 is 6.67%.
        let others = [9] + Array(repeating: 2, count: 28)
        #expect(StreakStanding(length: 4, among: others)?.topPercent == 7)
    }

    @Test func topHalfIsShownAndBelowItIsNot() {
        // Rank 5 of 10 is the top 50%, rank 6 isn't.
        #expect(StreakStanding(length: 5, among: [9, 8, 7, 6, 5, 4, 3, 2, 1])?.topPercent == 50)
        #expect(StreakStanding(length: 4, among: [9, 8, 7, 6, 5, 4, 3, 2, 1]) == nil)
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
        // Only the nine plausible lengths count, so the 500 doesn't outrank you.
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
