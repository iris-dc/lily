import Foundation
import Testing
@testable import lily

@MainActor
struct TranscriptScrollPolicyTests {
    typealias Snapshot = TranscriptScrollPolicy.Snapshot

    private func snapshot(offsetY: CGFloat = 0,
                          contentHeight: CGFloat = 2_000,
                          bottomInset: CGFloat = 80,
                          isAtBottom: Bool = true,
                          isNearTop: Bool = false) -> Snapshot {
        Snapshot(offsetY: offsetY,
                 contentHeight: contentHeight,
                 bottomInset: bottomInset,
                 isAtBottom: isAtBottom,
                 isNearTop: isNearTop)
    }

    /// The first page in place pins the bottom exactly once; a report without rows or without content is not the first page.
    @Test func pinsTheBottomOnceWhenTheFirstPageHasLaidOut() {
        var policy = TranscriptScrollPolicy()
        let slotOnly = snapshot(contentHeight: 28)
        #expect(policy.geometryChanged(from: .empty, to: slotOnly, hasRows: false, canLoadOlder: true) == .none)
        #expect(policy.geometryChanged(from: .empty, to: snapshot(contentHeight: 0), hasRows: true, canLoadOlder: true) == .none)
        #expect(policy.geometryChanged(from: .empty, to: snapshot(), hasRows: true, canLoadOlder: true) == .scrollToBottom)
        #expect(policy.hasSettled)
        #expect(policy.geometryChanged(from: snapshot(), to: snapshot(offsetY: 1), hasRows: true, canLoadOlder: true) == .none)
    }

    /// The initial layout lands near the top of a lazy stack; the older page must wait for the first settle.
    @Test func neverLoadsOlderBeforeTheFirstSettle() {
        var policy = TranscriptScrollPolicy()
        let nearTop = snapshot(isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: .empty, to: nearTop, hasRows: true, canLoadOlder: true) == .scrollToBottom)
    }

    @Test func loadsOlderNearTheTopOnlyWhenAPageIsAvailable() {
        var policy = settled()
        let nearTop = snapshot(offsetY: 10, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: false) == .none)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true) == .loadOlder)
    }

    /// The prepend is compensated by the height it added, measured against the reader's latest offset.
    @Test func restoresThePlaceAfterAnOlderPageWasPrepended() {
        var policy = settled()
        policy.willLoadOlder(at: snapshot(offsetY: 10, contentHeight: 2_000, isAtBottom: false, isNearTop: true))
        let stillWaiting = snapshot(offsetY: 40, contentHeight: 2_000, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: stillWaiting, hasRows: true, canLoadOlder: true) == .none)
        let grown = snapshot(offsetY: 40, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: stillWaiting, to: grown, hasRows: true, canLoadOlder: true) == .scrollTo(y: 1_540))
        #expect(policy.pendingRestore == nil)
    }

    /// While a page is pending, nothing else (not even another load) is asked for.
    @Test func holdsOtherActionsWhileAPageIsPending() {
        var policy = settled()
        policy.willLoadOlder(at: snapshot(offsetY: 0, isAtBottom: false, isNearTop: true))
        let nearTop = snapshot(offsetY: 0, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true) == .none)
        policy.didNotLoadOlder()
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true) == .loadOlder)
    }

    /// The keyboard or a growing composer changes the bottom inset; a list at the bottom stays at the bottom.
    @Test func followsAnInsetChangeOnlyWhileAtTheBottom() {
        var policy = settled()
        let before = snapshot(bottomInset: 80)
        let keyboardUp = snapshot(bottomInset: 380)
        #expect(policy.geometryChanged(from: before, to: keyboardUp, hasRows: true, canLoadOlder: true) == .scrollToBottom)
        let readingBefore = snapshot(offsetY: 500, isAtBottom: false)
        let readingAfter = snapshot(offsetY: 500, bottomInset: 380, isAtBottom: false)
        #expect(policy.geometryChanged(from: readingBefore, to: readingAfter, hasRows: true, canLoadOlder: true) == .none)
    }

    private func settled() -> TranscriptScrollPolicy {
        var policy = TranscriptScrollPolicy()
        _ = policy.geometryChanged(from: .empty, to: snapshot(), hasRows: true, canLoadOlder: true)
        return policy
    }
}
