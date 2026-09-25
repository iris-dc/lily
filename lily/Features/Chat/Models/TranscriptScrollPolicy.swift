import Foundation

/// What the chat transcript's scroll position does after each geometry report. Pure, so the rules are tested without
/// a view: the newest row is pinned above the composer once the first page has laid out (the default bottom anchor
/// ignores the composer's safe-area inset), an older page keeps what was on screen where it was (the prepended height
/// is added to the offset), an inset change at the bottom re-pins the bottom, and the page before is requested only
/// when the reader has scrolled near the top after that first settle, never during the initial layout.
nonisolated struct TranscriptScrollPolicy: Equatable, Sendable {
    struct Snapshot: Equatable, Sendable {
        var offsetY: CGFloat
        var contentHeight: CGFloat
        var bottomInset: CGFloat
        var isAtBottom: Bool
        var isNearTop: Bool

        static let empty = Snapshot(offsetY: 0, contentHeight: 0, bottomInset: 0, isAtBottom: true, isNearTop: false)
    }

    enum Action: Equatable, Sendable {
        case none
        case scrollToBottom
        case scrollTo(y: CGFloat)
        case loadOlder
    }

    private(set) var hasSettled = false
    /// The geometry an older page is being prepended to; cleared when the taller content has been laid out.
    private(set) var pendingRestore: Snapshot?

    /// Called before an older page is requested, with the geometry the reader currently sees.
    mutating func willLoadOlder(at snapshot: Snapshot) {
        pendingRestore = snapshot
    }

    /// Called when the requested page brought nothing to lay out (a failure or an empty page).
    mutating func didNotLoadOlder() {
        pendingRestore = nil
    }

    mutating func geometryChanged(from previous: Snapshot,
                                  to current: Snapshot,
                                  hasRows: Bool,
                                  canLoadOlder: Bool) -> Action {
        if let restore = pendingRestore {
            guard current.contentHeight != restore.contentHeight else {
                // Still waiting for the page; follow the reader so the restore lands where they are, not where they were.
                pendingRestore?.offsetY = current.offsetY
                return .none
            }
            pendingRestore = nil
            return .scrollTo(y: restore.offsetY + (current.contentHeight - restore.contentHeight))
        }
        guard hasSettled else {
            guard hasRows, current.contentHeight > 0 else { return .none }
            hasSettled = true
            return .scrollToBottom
        }
        if previous.bottomInset != current.bottomInset, current.isAtBottom {
            return .scrollToBottom
        }
        if current.isNearTop, canLoadOlder {
            return .loadOlder
        }
        return .none
    }
}
