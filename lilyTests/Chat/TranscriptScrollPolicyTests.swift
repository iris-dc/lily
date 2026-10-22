import Foundation
import SwiftUI
import Testing
@testable import lily

@MainActor
struct TranscriptScrollPolicyTests {
    typealias Snapshot = TranscriptScrollPolicy.Snapshot

    /// The oldest row before and after an older page is prepended.
    let oldest = "m10"
    private let older = "m1"

    func snapshot(offsetY: CGFloat = 0,
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
        #expect(policy.geometryChanged(from: .empty, to: slotOnly, hasRows: false, canLoadOlder: true, oldestID: nil) == .none)
        let noContent = snapshot(contentHeight: 0)
        #expect(policy.geometryChanged(from: .empty, to: noContent, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.geometryChanged(from: .empty, to: snapshot(), hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        #expect(policy.hasSettled)
        let nudged = snapshot(offsetY: 1)
        #expect(policy.geometryChanged(from: snapshot(), to: nudged, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// The initial layout lands near the top of a lazy stack; the older page must wait for the first settle.
    @Test func neverLoadsOlderBeforeTheFirstSettle() {
        var policy = TranscriptScrollPolicy()
        let nearTop = snapshot(isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: .empty, to: nearTop, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
    }

    @Test func loadsOlderNearTheTopOnlyWhenAPageIsAvailable() {
        var policy = settled()
        let nearTop = snapshot(offsetY: 10, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: false, oldestID: oldest)
                == .none)
        #expect(policy.geometryChanged(from: snapshot(), to: nearTop, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .loadOlder)
    }

    /// The prepend is compensated by the height it added, measured against the reader's latest offset.
    @Test func restoresThePlaceAfterAnOlderPageWasPrepended() {
        var policy = settled()
        policy.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let stillWaiting = snapshot(offsetY: 40, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: stillWaiting, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let grown = snapshot(offsetY: 40, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: stillWaiting, to: grown, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_540))
        #expect(policy.pendingRestore == nil)
    }

    /// While a page is pending, nothing else (not even another load) is asked for.
    @Test func holdsOtherActionsWhileAPageIsPending() {
        var policy = settled()
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
        var policy = settled()
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
        var policy = settled()
        policy.willLoadOlder(at: snapshot(offsetY: 10, isAtBottom: false, isNearTop: true), oldestID: oldest)
        let held = snapshot(offsetY: 25, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: snapshot(), to: held, hasRows: true, canLoadOlder: true, oldestID: older) == .none)
        #expect(policy.pendingRestore != nil)
        let laidOut = snapshot(offsetY: 25, contentHeight: 3_500, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: held, to: laidOut, hasRows: true, canLoadOlder: true, oldestID: older)
                == .scrollTo(y: 1_525))
    }

    @Test func aFailedPageDropsTheRestoreAndBottomGrowthIsThenPlainGeometry() {
        var policy = settled()
        policy.willLoadOlder(at: snapshot(offsetY: 300, isAtBottom: false, isNearTop: true), oldestID: oldest)
        policy.didNotLoadOlder()
        #expect(policy.pendingRestore == nil)
        let reading = snapshot(offsetY: 300, isAtBottom: false)
        let grewBelow = snapshot(offsetY: 300, contentHeight: 2_060, isAtBottom: false)
        #expect(policy.geometryChanged(from: reading, to: grewBelow, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.pendingRestore == nil)
    }

    /// The keyboard or a growing composer changes the bottom inset; a list at the bottom stays at the bottom.
    @Test func followsAnInsetChangeOnlyWhileAtTheBottom() {
        var policy = settled()
        let before = snapshot(bottomInset: 80)
        let keyboardUp = snapshot(bottomInset: 380)
        #expect(policy.geometryChanged(from: before, to: keyboardUp, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        let readingBefore = snapshot(offsetY: 500, isAtBottom: false)
        let readingAfter = snapshot(offsetY: 500, bottomInset: 380, isAtBottom: false)
        #expect(policy.geometryChanged(from: readingBefore, to: readingAfter, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        // A shrinking inset (the keyboard going, the composer back to one line) uncovers content; nothing to pin.
        #expect(policy.geometryChanged(from: keyboardUp, to: before, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// A block hiding rows, or a tombstone shorter than its bubble, shrinks the content.
    @Test func followsAContentShrinkOnlyWhileAtTheBottom() {
        var policy = settled()
        let shrunk = snapshot(contentHeight: 1_700)
        #expect(policy.geometryChanged(from: snapshot(), to: shrunk, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        let readingBefore = snapshot(offsetY: 500, isAtBottom: false)
        let readingAfter = snapshot(offsetY: 500, contentHeight: 1_700, isAtBottom: false)
        #expect(policy.geometryChanged(from: readingBefore, to: readingAfter, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// Only the caller's own row fetches a reader who scrolled away, once its growth is laid out; another member's row
    /// or a note leaves them reading. The follow is spent by that growth, and an own row appended at the bottom sets none.
    @Test func ownRowsBringAReaderWhoScrolledAwayBack() {
        let readingBefore = snapshot(offsetY: 500, isAtBottom: false)
        let readingAfter = snapshot(offsetY: 500, contentHeight: 2_300, isAtBottom: false)
        let later = snapshot(offsetY: 500, contentHeight: 2_600, isAtBottom: false)
        let unsent = ChatRow.pending(PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: .now))
        let note = ChatRow.system(.fixture(id: "s1", kind: .eventCreated))
        let cases: [(ChatRow?, Bool)] = [(unsent, true), (bubble(isOwn: true), true), (bubble(isOwn: false), false),
                                         (note, false), (.day(Date()), false), (nil, false)]
        for (row, follows) in cases {
            var policy = settled()
            policy.rowAppended(row, isAtBottom: false)
            let action = policy.geometryChanged(from: readingBefore,
                                                to: readingAfter,
                                                hasRows: true,
                                                canLoadOlder: true,
                                                oldestID: oldest)
            #expect(action == (follows ? .animateToBottom : .none), "\(row?.id ?? "nil")")
            #expect(policy.geometryChanged(from: readingAfter, to: later, hasRows: true, canLoadOlder: true, oldestID: oldest)
                    == .none, "nothing left to follow")
        }
        var atBottom = settled()
        atBottom.rowAppended(bubble(isOwn: true), isAtBottom: true)
        #expect(atBottom.geometryChanged(from: readingBefore,
                                         to: readingAfter,
                                         hasRows: true,
                                         canLoadOlder: true,
                                         oldestID: oldest) == .none)
    }

    /// Within `atBottomThreshold` of the content end is at the bottom; within `olderPageTriggerDistance` of the top,
    /// the top inset included, is near it.
    @Test func thresholdsMapGeometryToTheFlags() {
        var geometry = ScrollGeometry(contentOffset: CGPoint(x: 0, y: 1_180),
                                      contentSize: CGSize(width: 390, height: 2_000),
                                      contentInsets: EdgeInsets(top: 50, leading: 0, bottom: 80, trailing: 0),
                                      containerSize: CGSize(width: 390, height: 800))
        let reading = Snapshot(geometry)
        #expect(reading.isAtBottom, "the visible bottom is 20 pt above the end")
        #expect(!reading.isNearTop)
        #expect(reading.offsetY == 1_180 && reading.contentHeight == 2_000 && reading.bottomInset == 80)
        geometry.contentOffset.y = 1_170
        #expect(!Snapshot(geometry).isAtBottom, "30 pt short of the end")
        geometry.contentOffset.y = -50
        #expect(Snapshot(geometry).isNearTop, "the top inset exactly")
        geometry.contentOffset.y = 151
        #expect(!Snapshot(geometry).isNearTop, "201 pt past the top")
    }

    private func bubble(isOwn: Bool) -> ChatRow {
        .message(MessageRow(message: .fixture(id: "m1", senderUserID: isOwn ? "me" : "u-2"),
                            isOwn: isOwn,
                            senderName: isOwn ? "You" : "Marta",
                            isFirstInRun: true,
                            isLastInRun: true))
    }

    func settled() -> TranscriptScrollPolicy {
        var policy = TranscriptScrollPolicy()
        _ = policy.geometryChanged(from: .empty, to: snapshot(), hasRows: true, canLoadOlder: true, oldestID: oldest)
        return policy
    }
}
