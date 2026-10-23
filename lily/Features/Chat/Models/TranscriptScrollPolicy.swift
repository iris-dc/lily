import Foundation

/// What the chat transcript's scroll position does after each geometry report, each scroll phase and each appended row;
/// pure, so the rules can be checked without a view. Following the bottom is a state, not a reading of the geometry: it
/// starts with the first page's pin, any scroll that comes to rest away from the bottom ends it (the reader's, a tapped
/// quote's, VoiceOver's), and any rest at the bottom resumes it. While the reader follows, every change of the content's
/// height, of the bottom inset or of the visible height pins the bottom (a row growing in on the arrival clock, a lazy
/// stack correcting its estimates, a picture loading, the keyboard, a window resized), so the newest row stays on the
/// composer frame by frame and the rows above glide up with a row growing in. A report taken mid-layout, between a
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
        case scrollTo(y: CGFloat)
        case loadOlder
    }

    private(set) var hasSettled = false
    /// Whether the reader follows the bottom.
    private(set) var isFollowing = false
    /// The caller's own row arrived while they read older messages: the growth that lays it out is followed.
    private var followsNextGrowth = false
    /// The slide that fetches the reader is under way: its rest is the bottom, wherever the row's growth left it.
    private var isSliding = false
    /// The older page being prepended; cleared when the taller content has been laid out or the page brought nothing.
    private(set) var pendingRestore: PendingRestore?

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
        switch phase {
        case .touched:
            isFollowing = false
            isSliding = false
            followsNextGrowth = false
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

    mutating func geometryChanged(from previous: Snapshot,
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
        if isFollowing, current.movesTheBottom(from: previous) {
            return .scrollToBottom
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

    /// While an older page is pending: growth with the same oldest message is below the reader and becomes the new
    /// baseline; a moved oldest message at the old height is the page held but not laid out yet; the taller layout
    /// after it is the prepend, compensated against the reader's latest offset.
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
        return .scrollTo(y: restore.geometry.offsetY + (current.contentHeight - restore.geometry.contentHeight))
    }
}
