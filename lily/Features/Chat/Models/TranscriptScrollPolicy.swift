import Foundation

/// What the chat transcript's scroll position does after each geometry report and each appended row. Pure, so the
/// rules are tested without a view: the newest row is pinned above the composer once the first page has laid out (the
/// default bottom anchor ignores the composer's safe-area inset), an older page keeps what was on screen where it was
/// (the prepended height is added to the offset; the prepend is told from growth at the bottom by the oldest message
/// held, not by the height, so a live message or a system row's game landing during the round trip is never
/// compensated), an inset change or a shrink of the content at the bottom re-pins the bottom (the keyboard, a block
/// hiding a sender's rows), the page before is requested only when the reader has scrolled near the top after that
/// first settle, never during the initial layout, and an appended row is followed to the bottom when it is the
/// caller's own or the reader is already there.
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
        case scrollToBottom
        case scrollTo(y: CGFloat)
        case loadOlder
    }

    private(set) var hasSettled = false
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

    /// What the list does when a row is appended: the caller's rows always scroll to the bottom, any other row (another
    /// member's bubble, a system note) only while the reader is there, so reading older messages is never interrupted.
    static func rowAppended(_ row: ChatRow?, isAtBottom: Bool) -> Action {
        guard let row, row.isOwn || isAtBottom else { return .none }
        return .scrollToBottom
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
        if current.isAtBottom, previous.bottomInset != current.bottomInset || current.contentHeight < previous.contentHeight {
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
