import Foundation

/// Safe stand-ins for `<=`, `>=` and `max` on `Date`.
///
/// Don't compare dates with `<=` or `>=`, or pass them to `max`, which uses `>=`. Foundation marks
/// `Date.<=` and `Date.>=` `@backDeployed`, so each call goes through a check that picks the
/// system's copy when the OS reports a new enough Foundation. iOS 27.2 beta passes that check but
/// doesn't ship the symbol, so the call jumps to address 0 and the app crashes at launch (TestFlight,
/// build 4, in `Game.hasStarted`). `<`, `>` and `==` are ordinary symbols and safe.
extension Date {
    /// Whether this date is the same as or earlier than `other`: `self <= other`.
    public func isAtOrBefore(_ other: Date) -> Bool {
        !(other < self)
    }

    /// The later of this date and `other`: `max(self, other)`.
    public func later(_ other: Date) -> Date {
        self < other ? other : self
    }
}
