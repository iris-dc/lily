import Foundation

/// What the chat transcript's scroll position does after each geometry report and each appended row; pure, so the rules
/// can be checked without a view. The newest row is pinned above the composer once the first page has laid out (the
/// default bottom anchor ignores the composer's safe-area inset), an older page keeps what was on screen where it was,
/// a grown inset or a shrink of the content while at the bottom re-pins it (the keyboard, a block hiding a sender's
/// rows), growth below the fold while the reader was at the bottom (an appended row, which the transcript lets grow
/// unanchored) is followed with the arrival's animation, and the page before is requested only once the reader has
/// scrolled near the top after that first settle, never during the initial layout.
nonisolated struct TranscriptScrollPolicy: Equatable, Sendable {
    struct Snapshot: Equatable, Sendable {
        var offsetY: CGFloat
        var contentHeight: CGFloat
        var bottomInset: CGFloat
        var isAtBottom: Bool
        var isNearTop: Bool

        static let empty = Snapshot(offsetY: 0, contentHeight: 0, bottomInset: 0, isAtBottom: true, isNearTop: false)
    }

    /// An older page on its way: the geometry the page is prepended to and the oldest message held when it was asked for.
    struct PendingRestore: Equatable, Sendable {
        var geometry: Snapshot
        let oldestID: String?
    }

    enum Action: Equatable, Sendable {
        case none
        /// Pin the bottom at once.
        case scrollToBottom
        /// Slide to the bottom with the arrival's animation: rows above make room for the one that came.
        case animateToBottom
        case scrollTo(y: CGFloat)
        case loadOlder
    }

    private(set) var hasSettled = false
    /// The caller's own row was appended while they had scrolled away: the growth that lays it out is followed.
    private var followsNextGrowth = false
    /// A slide was just asked for: the report after it may shrink the content without a pin, since the lazy stack lays
    /// the appended row out below the fold at an estimated height first and corrects it a frame later, and a pin then
    /// would snap the slide to its end.
    private var slideJustStarted = false
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

    /// The caller's own row brings a reader who scrolled away back to the bottom once it is laid out; another member's
    /// or a system row never does, so reading older messages is never interrupted. A reader at the bottom is followed
    /// by the growth itself.
    mutating func rowAppended(_ row: ChatRow?, isAtBottom: Bool) {
        if let row, row.isOwn, !isAtBottom {
            followsNextGrowth = true
        }
    }

    mutating func geometryChanged(from previous: Snapshot,
                                  to current: Snapshot,
                                  hasRows: Bool,
                                  canLoadOlder: Bool,
                                  oldestID: String?) -> Action {
        if let restore = pendingRestore {
            return restoring(restore, at: current, oldestID: oldestID)
        }
        guard hasSettled else {
            guard hasRows, current.contentHeight > 0 else { return .none }
            hasSettled = true
            return .scrollToBottom
        }
        // Growth under a reader at the bottom is the appended row, laid out below the fold while the transcript lifts
        // its anchor; growth the anchor did follow (a bubble made taller by its picture) slides nowhere. Judged before
        // the inset rule: a send clears the composer, and a shorter composer in the same report must not pin the row at
        // once.
        if current.contentHeight > previous.contentHeight, previous.isAtBottom || followsNextGrowth {
            followsNextGrowth = false
            slideJustStarted = true
            return .animateToBottom
        }
        let correctsTheAppendedRow = slideJustStarted && current.contentHeight < previous.contentHeight
        slideJustStarted = false
        // A grown inset (the keyboard, a composer growing a line) covers the newest row; a shrunk one uncovers content
        // and the scroll view settles on the new bottom by itself, so pinning it would also cut a slide short.
        if current.isAtBottom, !correctsTheAppendedRow,
           previous.bottomInset < current.bottomInset || current.contentHeight < previous.contentHeight {
            return .scrollToBottom
        }
        if current.isNearTop, canLoadOlder {
            return .loadOlder
        }
        return .none
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
