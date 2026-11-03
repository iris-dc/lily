import Foundation
import Testing
@testable import lily

/// The older page: asked for near the top, the reader's place restored once the prepend has laid out, and the page before
/// that only once the restore has landed.
extension TranscriptScrollPolicyTests {
    /// The prepend is compensated by the height it added, measured against the reader's latest offset.
    @Test func restoresThePlaceAfterAnOlderPageWasPrepended() {
        var policy = reading()
        policy.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let stillWaiting = snapshot(offsetY: 40, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: stillWaiting, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let grown = snapshot(offsetY: 40, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: stillWaiting, to: grown, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_540))
        #expect(policy.pendingRestore == nil)
    }

    /// The restore lands a layout later; a report before it still reads the old offset near the top and must not ask for
    /// the page before, which would land the reader two pages up. The reader's touch frees the rule.
    @Test func noOlderPageIsAskedForUntilTheRestoreHasLanded() {
        var policy = reading()
        policy.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let grown = snapshot(offsetY: 10, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: grown, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_510))
        let corrected = snapshot(offsetY: 10, contentHeight: 3_480, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: grown, to: corrected, hasRows: true, canLoadOlder: true, oldestID: older)
                == .none, "the old offset before the restore lands")
        let landed = snapshot(offsetY: 1_490, contentHeight: 3_480, isAtBottom: false)
        #expect(policy.geometryChanged(from: corrected, to: landed, hasRows: true, canLoadOlder: true, oldestID: older)
                == .none)
        let backNearTop = snapshot(offsetY: 20, contentHeight: 3_480, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: landed, to: backNearTop, hasRows: true, canLoadOlder: true, oldestID: older)
                == .loadOlder, "once landed, the top asks for the page before as ever")

        var touched = reading()
        touched.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        _ = touched.geometryChanged(from: snapshot(), to: grown, hasRows: true, canLoadOlder: true, oldestID: older)
        touched.scrollPhaseChanged(to: .touched, at: grown)
        #expect(touched.geometryChanged(from: grown, to: corrected, hasRows: true, canLoadOlder: true, oldestID: older)
                == .loadOlder, "the reader's own scroll near the top asks as ever")
    }

    /// While a page is pending, nothing else (not even another load) is asked for.
    @Test func holdsOtherActionsWhileAPageIsPending() {
        var policy = reading()
        policy.willLoadOlder(at: snapshot(offsetY: 0, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let nearTop = snapshot(offsetY: 0, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        policy.didNotLoadOlder()
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .loadOlder)
    }

    /// Content growing below the reader during the round trip (a live line) is no prepend: it becomes the baseline and
    /// only the page is compensated.
    @Test func bottomGrowthWhileAnOlderPageIsPendingIsNotAPrepend() {
        var policy = reading()
        let waiting = snapshot(offsetY: 10, isAtBottom: false, isNearTop: true)
        policy.willLoadOlder(at: waiting, oldestID: oldest)
        let grewBelow = snapshot(offsetY: 10, contentHeight: 2_060, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: waiting, to: grewBelow, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.pendingRestore?.geometry.contentHeight == 2_060)
        let prepended = snapshot(offsetY: 10, contentHeight: 3_560, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: grewBelow, to: prepended, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_510))
        #expect(policy.pendingRestore == nil)
    }

    /// The model holds the page before the layout grows; a report in between keeps the restore and follows the reader.
    @Test func aPageHeldButNotYetLaidOutKeepsTheRestoreWaiting() {
        var policy = reading()
        policy.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let held = snapshot(offsetY: 25, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: held, hasRows: true, canLoadOlder: true, oldestID: older) == .none)
        #expect(policy.pendingRestore != nil)
        let laidOut = snapshot(offsetY: 25, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: held, to: laidOut, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_525))
    }

    @Test func aFailedPageDropsTheRestoreAndBottomGrowthIsThenPlainGeometry() {
        var policy = reading()
        policy.willLoadOlder(at: snapshot(offsetY: 300, isAtBottom: false, isNearTop: true), oldestID: oldest)
        policy.didNotLoadOlder()
        #expect(policy.pendingRestore == nil)
        let reading = snapshot(offsetY: 300, isAtBottom: false)
        let grewBelow = snapshot(offsetY: 300, contentHeight: 2_060, isAtBottom: false)
        #expect(policy.geometryChanged(from: reading, to: grewBelow, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.pendingRestore == nil)
    }
}
