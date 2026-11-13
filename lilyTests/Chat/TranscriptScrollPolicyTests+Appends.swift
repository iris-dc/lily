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
                == .glideToBottom, "a window resized is chrome motion, ridden like the keyboard")
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

    /// UIKit scrolls to the top on a tap of the status bar with no phase SwiftUI reports: the scroll view moves up on its
    /// own, which ends following from its first frame, so the growth a lazy stack measures on the way is not pinned; near
    /// the top the older page is asked for as after any scroll.
    @Test func aScrollUpTheReaderDidNotMakeEndsFollowingWithoutAPin() {
        var policy = settled()
        let atBottom = snapshot(offsetY: 1_200)
        // The first pin's landing: the report after a pin is never a scroll-up, so the rest comes first.
        #expect(policy.geometryChanged(from: snapshot(), to: atBottom, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        let firstFrame = snapshot(offsetY: 1_180, contentHeight: 2_030, isAtBottom: false)
        #expect(policy.geometryChanged(from: atBottom, to: firstFrame, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(!policy.isFollowing)
        let nearTop = snapshot(offsetY: 10, contentHeight: 2_200, isAtBottom: false, isNearTop: true)
        #expect(policy.geometryChanged(from: firstFrame, to: nearTop, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .loadOlder)
    }

    /// An append takes the previous bubble's time line with it: the content shrinks, the pin lands a report later with
    /// the offset a few points lower and the content as it was, which is no scroll of anyone's, so the reader keeps
    /// following and the row growing in is pinned (on the simulator every other send stayed under the composer without
    /// this). The pin the transcript makes when it comes back on screen is one of ours too.
    @Test func thePinsOwnLandingIsNotAScrollUp() {
        var policy = settled()
        let atBottom = snapshot(offsetY: 660, contentHeight: 1_174)
        let shrunk = snapshot(offsetY: 660, contentHeight: 1_105)
        #expect(policy.geometryChanged(from: atBottom, to: shrunk, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        let landed = snapshot(offsetY: 648, contentHeight: 1_105)
        #expect(policy.geometryChanged(from: shrunk, to: landed, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.isFollowing, "the landing is ours")
        let grown = snapshot(offsetY: 648, contentHeight: 1_116)
        #expect(policy.geometryChanged(from: landed, to: grown, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)

        var returned = settled()
        #expect(returned.reappeared() == .scrollToBottom)
        let before = snapshot(offsetY: 600)
        let afterReturn = snapshot(offsetY: 590, contentHeight: 2_000)
        #expect(returned.geometryChanged(from: before, to: afterReturn, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(returned.isFollowing)
        var reader = reading()
        #expect(reader.reappeared() == .none, "a reader of older messages is left where they are")
    }

    /// A pin that moved nothing (the reader came back already at the bottom) sends no landing report: the next report is
    /// judged as any other, so a status-bar scroll whose first frame measures rows still ends following and is not pinned.
    @Test func aScrollUpAfterAPinThatNeverLandedEndsFollowing() {
        var policy = settled()
        #expect(policy.reappeared() == .scrollToBottom)
        let atBottom = snapshot(offsetY: 1_200)
        let firstFrame = snapshot(offsetY: 1_180, contentHeight: 2_030, isAtBottom: false)
        #expect(policy.geometryChanged(from: atBottom, to: firstFrame, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(!policy.isFollowing)
        let nextFrame = snapshot(offsetY: 900, contentHeight: 2_080, isAtBottom: false)
        #expect(policy.geometryChanged(from: firstFrame, to: nextFrame, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none, "nothing fights the scroll to the top")
    }

    /// A pin can land while the arriving row is still growing in: the offset is lower and the content taller, but the
    /// landing ends on the bottom, so the reader keeps following and the growth is pinned.
    @Test func aPinLandingWhileTheRowStillGrowsKeepsFollowing() {
        var policy = settled()
        let atBottom = snapshot(offsetY: 660, contentHeight: 1_174)
        let shrunk = snapshot(offsetY: 660, contentHeight: 1_105)
        #expect(policy.geometryChanged(from: atBottom, to: shrunk, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        let landedGrowing = snapshot(offsetY: 648, contentHeight: 1_116)
        #expect(policy.geometryChanged(from: shrunk, to: landedGrowing, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        #expect(policy.isFollowing, "the landing is ours even while the row grows")
    }

    /// A pin after a shrink lowers the offset too (a tombstone, the lazy stack's correction), and so does the keyboard
    /// going with its inset: the reader keeps following, pinned or gliding.
    @Test func aLowerOffsetWithAShrinkOrAnInsetChangeIsNotAScroll() {
        var policy = settled()
        let atBottom = snapshot(offsetY: 1_200)
        let shrunk = snapshot(offsetY: 1_150, contentHeight: 1_950)
        #expect(policy.geometryChanged(from: atBottom, to: shrunk, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
        let keyboardGone = snapshot(offsetY: 1_070, contentHeight: 1_950, bottomInset: 0)
        #expect(policy.geometryChanged(from: shrunk, to: keyboardGone, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .glideToBottom)
        #expect(policy.isFollowing)
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

    /// The keyboard rises after a send: the reader who follows rides with it; one who reads older messages is not moved.
    @Test func aGrownInsetGlidesTheReaderWhoFollows() {
        var policy = settled()
        let keyboardUp = snapshot(bottomInset: 417, isAtBottom: false)
        #expect(policy.geometryChanged(from: snapshot(), to: keyboardUp, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .glideToBottom)
        var reader = reading()
        let readingBefore = snapshot(offsetY: 300, isAtBottom: false)
        let readingKeyboard = snapshot(offsetY: 300, bottomInset: 417, isAtBottom: false)
        #expect(reader.geometryChanged(from: readingBefore,
                                       to: readingKeyboard,
                                       hasRows: true,
                                       canLoadOlder: true,
                                       oldestID: oldest) == .none)
    }

    /// The glide's own animation frames lower the offset on the keyboard's way down: they end nothing, the rest at
    /// the bottom resumes the exact pin, and the reader's touch takes over as ever.
    @Test func aGlidesOwnFramesDoNotEndFollowing() {
        var policy = settled()
        let keyboardGoing = snapshot(offsetY: 1_200, bottomInset: 0)
        let before = snapshot(offsetY: 1_200)
        #expect(policy.geometryChanged(from: before, to: keyboardGoing, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .glideToBottom)
        let glideFrame = snapshot(offsetY: 1_150, bottomInset: 0)
        #expect(policy.geometryChanged(from: keyboardGoing, to: glideFrame, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.isFollowing, "the glide's frames are not the reader's scroll")
        // A deep lazy room re-estimates unmeasured rows while the keyboard resizes it: mid-ride content motion
        // re-aims the glide rather than pinning, which cut the ride to a jump.
        let reEstimated = snapshot(offsetY: 1_150, contentHeight: 2_075, bottomInset: 0)
        #expect(policy.geometryChanged(from: glideFrame, to: reEstimated, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .glideToBottom)
        #expect(policy.scrollPhaseChanged(to: .resting, at: snapshot(bottomInset: 0)) == .scrollToBottom)
        #expect(policy.isFollowing)
        var touched = settled()
        let keyboardUp = snapshot(bottomInset: 380)
        _ = touched.geometryChanged(from: snapshot(), to: keyboardUp, hasRows: true, canLoadOlder: true, oldestID: oldest)
        touched.scrollPhaseChanged(to: .touched, at: keyboardUp)
        touched.scrollPhaseChanged(to: .resting, at: snapshot(offsetY: 400, bottomInset: 380, isAtBottom: false))
        #expect(!touched.isFollowing, "the reader's touch during the glide takes over")
    }

    /// Under Reduce Motion the glide is applied as an instant pin and the policy hears it: the ride's flag does not
    /// wait for a rest that never comes, the landing is exempt like any pin's, and a later scroll up is the reader's.
    @Test func aGlideLandedAtOnceLeavesNoRideBehind() {
        var policy = settled()
        let keyboardUp = snapshot(offsetY: 1_200, bottomInset: 380)
        let keyboardGone = snapshot(offsetY: 1_200)
        #expect(policy.geometryChanged(from: keyboardUp, to: keyboardGone, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .glideToBottom)
        policy.glideLandedAtOnce()
        let landing = snapshot(offsetY: 900)
        #expect(policy.geometryChanged(from: keyboardGone, to: landing, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(policy.isFollowing, "the instant pin's landing is ours")
        let scrolledUp = snapshot(offsetY: 700)
        #expect(policy.geometryChanged(from: landing, to: scrolledUp, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .none)
        #expect(!policy.isFollowing, "a scroll up after the landing is the reader's")
    }

    /// A report that moves the content and the chrome together (a send whose answer shrinks the composer) pins at
    /// once: only a chrome-only change rides the keyboard's spring.
    @Test func anInsetChangeWithAContentChangePinsAtOnce() {
        var policy = settled()
        let both = snapshot(contentHeight: 2_050, bottomInset: 380)
        #expect(policy.geometryChanged(from: snapshot(), to: both, hasRows: true, canLoadOlder: true, oldestID: oldest)
                == .scrollToBottom)
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
