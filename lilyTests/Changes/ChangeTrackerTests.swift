import Observation
import Testing
@testable import lily

@MainActor
struct ChangeTrackerTests {
    @Test func startsAtVersionZeroAndCountsEveryChange() {
        let tracker = ChangeTracker()
        #expect(tracker.version == 0)

        tracker.recordChange()
        tracker.recordChange()

        #expect(tracker.version == 2)
    }

    /// Views observe `version` to reload; a change that nobody is told about would leave them stale.
    @Test func aChangeNotifiesObservationTracking() async {
        let tracker = ChangeTracker()
        await confirmation { changed in
            withObservationTracking {
                _ = tracker.version
            } onChange: {
                changed()
            }
            tracker.recordChange()
        }
    }
}
