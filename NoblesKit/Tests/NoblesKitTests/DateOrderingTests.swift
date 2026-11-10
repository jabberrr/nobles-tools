import Foundation
import Testing
@testable import NoblesKit

struct DateOrderingTests {
    private let early = Date(timeIntervalSinceReferenceDate: 100)
    private let late = Date(timeIntervalSinceReferenceDate: 200)

    @Test func comparesAtOrBefore() {
        #expect(early.isAtOrBefore(late))
        #expect(early.isAtOrBefore(early))
        #expect(!late.isAtOrBefore(early))
    }

    @Test func picksTheLater() {
        #expect(early.later(late) == late)
        #expect(late.later(early) == late)
        #expect(early.later(early) == early)
    }
}
