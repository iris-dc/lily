import Foundation

/// What the chat transcript's scroll position does after each geometry report, each scroll phase and each appended row;
/// pure, so the rules can be checked without a view. Following the bottom is a state, not a reading of the geometry: it
/// starts with the first page's pin, any scroll that comes to rest away from the bottom ends it (the reader's, a tapped
/// quote's, VoiceOver's), so does a scroll the scroll view makes on its own from its first frame (UIKit's scroll to the
/// top on a tap of the status bar, which SwiftUI reports no phase for), and any rest at the bottom resumes it. While
/// the reader follows, every change of the content's height pins the bottom (a row growing in on the arrival clock, a
/// lazy stack correcting its estimates, a picture loading), so the newest row stays on the composer frame by frame and
/// the rows above glide up with a row growing in; a change of the bottom inset or of the visible height alone (the
/// keyboard, the composer growing a line, a window resized) rides to the bottom on the keyboard's own spring instead
/// (`glideToBottom`), so the rows travel with the chrome rather than jumping under it. A report taken mid-layout, between a
/// safe-area change and the inset that follows it, may read as away from the bottom; it changes nothing, since only a
/// rest moves the state. A reader of older messages is left where they are, an older page keeps what was on screen
/// where it was, and the page before is requested only once the reader has scrolled near the top after the first
/// settle. The caller's own row, sent while they read older messages, slides them back down; the slide's rest resumes
/// following and pins, wherever the growing row left it.
nonisolated struct TranscriptScrollPolicy: Equatable, Sendable {
    struct Snapshot: Equatable, Sendable {
        var offsetY: CGFloat
        /// The content's height as SwiftUI reports it: in a lazy stack it includes estimates of rows not measured yet,
        /// so it tells that the content changed, not where its end is.
        var contentHeight: CGFloat
        var bottomInset: CGFloat
        /// The scroll view's height less its insets.
        var visibleHeight: CGFloat
        /// Whether the content's end is on the composer, within `atBottomThreshold`, as the transcript reads it from
        /// where the end actually is on screen.
        var isAtBottom: Bool
        var isNearTop: Bool

        static let empty = Snapshot(offsetY: 0,
                                    contentHeight: 0,
                                    bottomInset: 0,
                                    visibleHeight: 0,
                                    isAtBottom: true,
                                    isNearTop: false)

        /// Whether the layout moved the bottom: the content, the inset or the visible height changed.
        func movesTheBottom(from previous: Snapshot) -> Bool {
            contentHeight != previous.contentHeight || bottomInset != previous.bottomInset
                || visibleHeight != previous.visibleHeight
        }

        /// Whether the scroll view moved up, read against the report before: the offset fell while the content did not
        /// shrink and neither the inset nor the visible height changed. A pin lowers the offset only after a shrink, and
        /// its landing is the report after it, which the policy exempts; UIKit's scroll to the top on a tap of the
        /// status bar is the one scroll that fits, and a lazy stack measuring rows on the way only grows.
        func wasScrolledUp(from previous: Snapshot) -> Bool {
            offsetY < previous.offsetY && contentHeight >= previous.contentHeight
                && bottomInset == previous.bottomInset && visibleHeight == previous.visibleHeight
        }
    }

    /// An older page on its way: the geometry the page is prepended to and the oldest message held when it was asked for.
    struct PendingRestore: Equatable, Sendable {
        var geometry: Snapshot
        let oldestID: String?
    }

    /// The scroll's phase as the rules need it: the reader's finger on it, at rest, or anything else (a fling running
    /// out, an animated scroll).
    enum Phase: Equatable, Sendable {
        case touched
        case resting
        case moving
    }

    enum Action: Equatable, Sendable {
        case none
        /// Pin the bottom at once.
        case scrollToBottom
        /// Slide to the bottom with the arrival's animation: the caller's own row fetches a reader of older messages.
        case animateToBottom
        /// Ride to the bottom on the keyboard's spring: the bottom inset or the visible height moved while the
        /// content stayed (the keyboard, the composer growing a line), so the rows travel with the chrome instead of
        /// jumping under it.
        case glideToBottom
        case scrollTo(y: CGFloat)
        case loadOlder
    }

    private(set) var hasSettled = false
    /// Whether the reader follows the bottom.
    private(set) var isFollowing = false
    /// The caller's own row arrived while they read older messages: the growth that lays it out is followed.
    private var followsNextGrowth = false
    /// A slide (the own row fetching a reader of older messages) or a glide (the inset ride) is under way: its rest
    /// is the bottom, wherever the motion left it.
    private var isSliding = false
    /// The older page being prepended; cleared when the taller content has been laid out or the page brought nothing.
    private(set) var pendingRestore: PendingRestore?
    /// A restore asked for and not yet seen to move the offset: until it has, a report near the top is the old place,
    /// not the reader's, and asks for no page.
    private var isRestoreLanding = false
    /// The last action was a pin: the report after it, when only the offset moved, shows the pin landing, whose offset
    /// is ours, lower when the content had shrunk (the previous bubble's time line going with an append), never a scroll
    /// of the reader's or UIKit's.
    private var lastActionWasPin = false

    /// Called before an older page is requested, with the geometry the reader currently sees and the oldest message held.
    mutating func willLoadOlder(at snapshot: Snapshot, oldestID: String?) {
        pendingRestore = PendingRestore(geometry: snapshot, oldestID: oldestID)
    }

    /// Called when the requested page brought nothing to lay out (a failure or an empty page).
    mutating func didNotLoadOlder() {
        pendingRestore = nil
    }

    /// A row arrived at the end. The caller's own brings a reader of older messages back to the bottom once it is laid
    /// out; another member's or a system row never does, so reading older messages is never interrupted.
    mutating func rowArrived(_ row: ChatRow?) {
        guard hasSettled, !isFollowing, let row, row.isOwn else { return }
        followsNextGrowth = true
    }

    /// The reader's touch suspends following and takes over a slide; a rest decides. Answers the pin a slide's rest
    /// needs: the row kept growing after the slide was aimed.
    @discardableResult
    mutating func scrollPhaseChanged(to phase: Phase, at snapshot: Snapshot) -> Action {
        let action = judgePhase(phase, at: snapshot)
        lastActionWasPin = action == .scrollToBottom
        return action
    }

    /// The transcript is back on screen: a reader who follows is pinned before the first report, since the bottom may
    /// have moved while the screen was covered.
    mutating func reappeared() -> Action {
        guard isFollowing else { return .none }
        lastActionWasPin = true
        return .scrollToBottom
    }

    /// The transcript applied a glide as an instant pin (Reduce Motion animates nothing): there is no ride to rest,
    /// so the flag goes now and the landing report is exempt like any pin's.
    mutating func glideLandedAtOnce() {
        isSliding = false
        lastActionWasPin = true
    }

    mutating func geometryChanged(from previous: Snapshot,
                                  to current: Snapshot,
                                  hasRows: Bool,
                                  canLoadOlder: Bool,
                                  oldestID: String?) -> Action {
        let action = judge(from: previous, to: current, hasRows: hasRows, canLoadOlder: canLoadOlder, oldestID: oldestID)
        lastActionWasPin = action == .scrollToBottom
        return action
    }

    private mutating func judgePhase(_ phase: Phase, at snapshot: Snapshot) -> Action {
        switch phase {
        case .touched:
            isFollowing = false
            isSliding = false
            followsNextGrowth = false
            isRestoreLanding = false
        case .resting:
            if isSliding {
                isSliding = false
                follow()
                return .scrollToBottom
            }
            if snapshot.isAtBottom, hasSettled {
                follow()
            } else {
                isFollowing = false
            }
        case .moving:
            break
        }
        return .none
    }

    private mutating func judge(from previous: Snapshot,
                                to current: Snapshot,
                                hasRows: Bool,
                                canLoadOlder: Bool,
                                oldestID: String?) -> Action {
        // A reader who follows does not care where older rows land: the bottom is pinned as ever.
        if isFollowing { pendingRestore = nil }
        if let restore = pendingRestore {
            followsNextGrowth = false
            return restoring(restore, at: current, oldestID: oldestID)
        }
        guard hasSettled else {
            guard hasRows, current.contentHeight > 0 else { return .none }
            hasSettled = true
            follow()
            return .scrollToBottom
        }
        if followsNextGrowth, current.contentHeight > previous.contentHeight {
            followsNextGrowth = false
            isSliding = true
            return .animateToBottom
        }
        // Ends from the first frame, so no pin fights the scroll; the state has no rest to wait for. The report after a
        // pin of ours is its landing when it moved only the offset or ended on the bottom (a row still growing in as it
        // lands); a pin that moved nothing sends no report, so the next one may be a scroll whose first frame measures
        // rows and has already left the bottom.
        let isPinLanding = lastActionWasPin
            && (current.contentHeight == previous.contentHeight || current.isAtBottom)
        // A glide's own frames lower the offset on the keyboard's way down; only the reader's touch or rest ends it.
        if isFollowing, !isPinLanding, !isSliding, current.wasScrolledUp(from: previous) {
            isFollowing = false
        }
        if isFollowing, current.movesTheBottom(from: previous) {
            return bottomMoved(from: previous, to: current)
        }
        if isRestoreLanding {
            guard current.offsetY != previous.offsetY else { return .none }
            isRestoreLanding = false
        }
        if current.isNearTop, canLoadOlder {
            return .loadOlder
        }
        return .none
    }

    private mutating func follow() {
        isFollowing = true
        followsNextGrowth = false
    }

    /// Content motion is pinned at once, frame by frame; chrome motion alone (the bottom inset, the visible height)
    /// rides to the bottom on the keyboard's spring, and its rest is the bottom like a slide's. While the ride runs,
    /// content motion re-aims it instead of pinning: in a deep lazy room the keyboard's resize makes the stack
    /// re-estimate unmeasured rows over the next frames, and a pin there cut the ride to a jump (seen 2026-11-13).
    private mutating func bottomMoved(from previous: Snapshot, to current: Snapshot) -> Action {
        if isSliding { return .glideToBottom }
        guard current.contentHeight == previous.contentHeight else { return .scrollToBottom }
        isSliding = true
        return .glideToBottom
    }

    /// While an older page is pending: growth with the same oldest message is below the reader and becomes the new
    /// baseline; a moved oldest message at the old height is the page held but not laid out yet; the taller layout
    /// after it is the prepend, compensated against the reader's latest offset. The compensation lands a layout later:
    /// a report before it (a lazy stack correcting the page's estimates) still reads the old offset, near the top.
    private mutating func restoring(_ restore: PendingRestore, at current: Snapshot, oldestID: String?) -> Action {
        guard oldestID != restore.oldestID else {
            pendingRestore?.geometry.contentHeight = current.contentHeight
            pendingRestore?.geometry.offsetY = current.offsetY
            return .none
        }
        guard current.contentHeight != restore.geometry.contentHeight else {
            pendingRestore?.geometry.offsetY = current.offsetY
            return .none
        }
        pendingRestore = nil
        isRestoreLanding = true
        return .scrollTo(y: restore.geometry.offsetY + (current.contentHeight - restore.geometry.contentHeight))
    }
}
