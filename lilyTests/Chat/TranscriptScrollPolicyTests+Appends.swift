import Foundation
import Testing
@testable import lily

/// Following the bottom as the reader's state, and what it pins while rows arrive.
extension TranscriptScrollPolicyTests {
    /// An arriving row grows the content frame by frame under a reader who follows: each frame is pinned, the lazy
    /// stack's correction and the previous bubble losing its time line too; a report of the scroll alone asks for
    /// nothing, and a reader of older messages is left alone.
    @Test func everyFrameOfARowGrowingInIsPinnedWhileFollowing() {
        var policy = settled()
        var previous = snapshot()
        for height in [2_077.0, 2_000, 2_005, 2_020, 2_041, 2_057] {
            let frame = snapshot(offsetY: height - 2_000, contentHeight: height)
            #expect(policy.geometryChanged(from: previous, to: frame, hasRows: true, canLoadOlder: true, oldestID: oldest)
                    == .scrollToBottom)
            previous = frame
        }
        let still = snapshot(offsetY: 58, contentHeight: 2_057)
        #expect(policy.geometryChanged(from: previous, to: still, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        var reader = reading()
        let readingBefore = snapshot(offsetY: 300, isAtBottom: false)
        let grewBelow = snapshot(offsetY: 300, contentHeight: 2_057, isAtBottom: false)
        #expect(reader.geometryChanged(from: readingBefore, to: grewBelow, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// A report taken mid-layout (the safe area already changed, its inset not yet) reads as away from the bottom: the
    /// reader still follows, and the change in it is pinned; a visible height that changes alone is pinned too.
    @Test func aReportThatReadsAwayDoesNotEndFollowing() {
        var policy = settled()
        let midLayout = snapshot(offsetY: 0, contentHeight: 2_300, isAtBottom: false)
        #expect(policy.geometryChanged(from: snapshot(), to: midLayout, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        #expect(policy.isFollowing, "only a rest moves the state")
        var resized = midLayout
        resized.visibleHeight = 500
        #expect(policy.geometryChanged(from: midLayout, to: resized, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom, "a window resized")
    }

    /// Any scroll that rests away from the bottom ends following, a tapped quote's or VoiceOver's as much as the
    /// reader's: nothing pulls them back down while they read.
    @Test func aProgrammaticScrollRestingAwayEndsFollowing() {
        var policy = settled()
        policy.scrollPhaseChanged(to: .moving, at: snapshot())
        policy.scrollPhaseChanged(to: .resting, at: snapshot(offsetY: 400, isAtBottom: false))
        #expect(!policy.isFollowing)
        let reading = snapshot(offsetY: 400, isAtBottom: false)
        let corrected = snapshot(offsetY: 400, contentHeight: 2_100, isAtBottom: false)
        #expect(policy.geometryChanged(from: reading, to: corrected, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
    }

    /// The slide that fetches the reader is aimed before the row has grown in: its rest resumes following and pins,
    /// wherever the row left it; the reader's touch during it takes over.
    @Test func theSlidesRestResumesFollowingAndPins() {
        var policy = reading()
        policy.rowArrived(bubble(isOwn: true))
        let before = snapshot(offsetY: 300, isAtBottom: false)
        let grown = snapshot(offsetY: 300, contentHeight: 2_010, isAtBottom: false)
        #expect(policy.geometryChanged(from: before, to: grown, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .animateToBottom)
        #expect(policy.scrollPhaseChanged(to: .resting, at: snapshot(contentHeight: 2_060, isAtBottom: false))
                == .scrollToBottom)
        #expect(policy.isFollowing)
        var touched = reading()
        touched.rowArrived(bubble(isOwn: true))
        touched.scrollPhaseChanged(to: .touched, at: before)
        #expect(touched.geometryChanged(from: before, to: grown, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none, "the reader's touch cancels the fetch")
    }

    /// A reader who follows is pinned while an older page loads (a short room loads it from the bottom), and the page
    /// is no restore for them.
    @Test func aFollowingReaderIsPinnedWhileAnOlderPageLoads() {
        var policy = settled()
        policy.willLoadOlder(at: snapshot(), oldestID: oldest)
        let grown = snapshot(contentHeight: 2_057)
        #expect(policy.geometryChanged(from: snapshot(), to: grown, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        #expect(policy.pendingRestore == nil)
    }

    /// The reader's touch suspends following; letting go away from the bottom ends it, coming to rest at the bottom
    /// (after a fling or by itself) resumes it.
    @Test func theReadersOwnScrollDecidesWhetherTheyFollow() {
        var policy = settled()
        policy.scrollPhaseChanged(to: .touched, at: snapshot())
        #expect(!policy.isFollowing)
        policy.scrollPhaseChanged(to: .moving, at: snapshot(offsetY: 400, isAtBottom: false))
        policy.scrollPhaseChanged(to: .resting, at: snapshot(offsetY: 500, isAtBottom: false))
        #expect(!policy.isFollowing)
        policy.scrollPhaseChanged(to: .touched, at: snapshot(offsetY: 500, isAtBottom: false))
        policy.scrollPhaseChanged(to: .resting, at: snapshot())
        #expect(policy.isFollowing, "a rest at the bottom resumes following")
    }

    /// The keyboard rises after a send: the reader who follows is pinned; one who reads older messages is not.
    @Test func aGrownInsetPinsTheReaderWhoFollows() {
        var policy = settled()
        let keyboardUp = snapshot(bottomInset: 417, isAtBottom: false)
        #expect(policy.geometryChanged(from: snapshot(), to: keyboardUp, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        var reader = reading()
        let readingBefore = snapshot(offsetY: 300, isAtBottom: false)
        let readingKeyboard = snapshot(offsetY: 300, bottomInset: 417, isAtBottom: false)
        #expect(reader.geometryChanged(from: readingBefore,
                                       to: readingKeyboard,
                                       hasRows: true,
                                       canLoadOlder: true,
                                       oldestID: oldest) == .none)
    }

    /// Before the first settle there is no reader to follow or fetch.
    @Test func nothingFollowsBeforeTheFirstSettle() {
        var policy = TranscriptScrollPolicy()
        #expect(!policy.isFollowing)
        policy.rowArrived(.pending(PendingMessage(draft: MessageDraft(clientMessageID: "c-1"), sentAt: .now)))
        policy.scrollPhaseChanged(to: .resting, at: snapshot())
        #expect(!policy.isFollowing)
    }
}
