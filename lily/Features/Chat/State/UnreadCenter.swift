import Foundation
import Observation

/// Which rooms hold messages the caller has not seen: the Mine load says so for every group (`membership.hasUnread`),
/// live envelopes for the subscribed rooms, and the open chat clears its own. Feeds the tab badge and the row dots.
/// Message ids sort like ULIDs, so "newer" is a string comparison throughout.
@Observable
final class UnreadCenter: SessionObserver {
    private(set) var unreadGroupIDs: Set<String> = []
    /// The newest message marked unread live, per room, while that mark stands.
    private var liveUnreadIDs: [String: String] = [:]
    /// The newest message read here, per room.
    private var readIDs: [String: String] = [:]

    /// What the tab badge shows; hidden at zero.
    var count: Int { unreadGroupIDs.count }

    func hasUnread(groupID: String) -> Bool {
        unreadGroupIDs.contains(groupID)
    }

    /// A Mine load. The snapshot is the backend's view when it was asked and may predate what happened here since, so
    /// it is merged, not copied: a live mark stays while it is newer than the snapshot's read marker, and the
    /// snapshot's flag is taken only while its newest message is newer than what was read here.
    func apply(groups: [SportGroup]) {
        unreadGroupIDs = Set(groups.filter(isUnread).map(\.id))
        liveUnreadIDs = liveUnreadIDs.filter { unreadGroupIDs.contains($0.key) }
    }

    func markUnread(groupID: String, messageID: String) {
        unreadGroupIDs.insert(groupID)
        liveUnreadIDs[groupID] = max(liveUnreadIDs[groupID] ?? "", messageID)
    }

    /// The caller saw the room up to `messageID` (the newest row on screen); a room the caller lost passes none.
    func markRead(groupID: String, upTo messageID: String? = nil) {
        unreadGroupIDs.remove(groupID)
        liveUnreadIDs[groupID] = nil
        if let messageID { readIDs[groupID] = max(readIDs[groupID] ?? "", messageID) }
    }

    func sessionDidEnd() {
        unreadGroupIDs.removeAll()
        liveUnreadIDs.removeAll()
        readIDs.removeAll()
    }

    private func isUnread(_ group: SportGroup) -> Bool {
        if let liveID = liveUnreadIDs[group.id], liveID > (group.membership?.lastReadMessageId ?? "") { return true }
        guard group.hasUnread else { return false }
        guard let readID = readIDs[group.id] else { return true }
        return (group.lastMessageId ?? "") > readID
    }
}
