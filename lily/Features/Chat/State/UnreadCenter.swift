import Foundation
import Observation

/// Which rooms hold messages the caller has not seen: the Mine load says so for every group (`membership.hasUnread`),
/// live envelopes for the subscribed rooms, and the open chat clears its own. Feeds the tab badge and the row dots.
@Observable
final class UnreadCenter: SessionObserver {
    private(set) var unreadGroupIDs: Set<String> = []

    /// What the tab badge shows; hidden at zero.
    var count: Int { unreadGroupIDs.count }

    func hasUnread(groupID: String) -> Bool {
        unreadGroupIDs.contains(groupID)
    }

    /// The Mine list as it was just loaded replaces what is known: it is consistent, so it is never older than a
    /// live mark.
    func apply(groups: [SportGroup]) {
        unreadGroupIDs = Set(groups.filter(\.hasUnread).map(\.id))
    }

    func markUnread(groupID: String) {
        unreadGroupIDs.insert(groupID)
    }

    func markRead(groupID: String) {
        unreadGroupIDs.remove(groupID)
    }

    func sessionDidEnd() {
        unreadGroupIDs.removeAll()
    }
}
