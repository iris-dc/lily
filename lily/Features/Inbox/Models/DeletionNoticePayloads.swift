import Foundation

/// The `eventCancelled` payload of an `event_cancelled` item: the snapshot of an upcoming game its host's account
/// deletion removed. The event itself is gone (delete-plus-notify), so the card opens nothing.
nonisolated struct EventCancelledPayload: Hashable, Codable, Sendable {
    let eventId: String
    let title: String
    let startsAt: Date
}

/// The `groupOwnershipTransferred` payload of a `group_ownership_transferred` item: the group the deletion job handed
/// to the caller, its name a snapshot taken when the handoff committed.
nonisolated struct GroupOwnershipTransferredPayload: Hashable, Codable, Sendable {
    let groupId: String
    let groupName: String
}
