import Foundation
import Testing
@testable import lily

struct TimeIntervalUnitsTests {
    /// Every fixture date is built from these two; a slip in either would shift them all silently.
    @Test func hourAndDayAreTheirSecondCounts() {
        #expect(TimeInterval.hour == 3600)
        #expect(TimeInterval.day == 24 * TimeInterval.hour)
    }
}
