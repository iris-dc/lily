import Foundation

/// One page of the inbox, ascending by id, as `GET /api/me/inbox` answers it. `hasMore` points to older items and
/// `nextBefore` is the id to page before for them; `lastReadId` is the caller's read marker as the backend holds it.
nonisolated struct InboxPage: Hashable, Codable, Sendable {
    let items: [InboxItem]
    let hasMore: Bool
    let nextBefore: String?
    let lastReadId: String?

    init(items: [InboxItem], hasMore: Bool = false, nextBefore: String? = nil, lastReadId: String? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.nextBefore = nextBefore
        self.lastReadId = lastReadId
    }
}

/// Answer of `POST /api/me/inbox/{itemId}/accept`: the item as accepted and the group, membership included.
nonisolated struct InviteAcceptance: Hashable, Codable, Sendable {
    let item: InboxItem
    let group: SportGroup
}

/// Answer of `POST /api/me/inbox/{itemId}/decline`.
nonisolated struct InviteDeclination: Hashable, Codable, Sendable {
    let item: InboxItem
}

/// Body of `PUT /api/me/inbox/read`.
nonisolated struct InboxReadPayload: Encodable, Equatable, Sendable {
    let itemId: String
}

/// Answer of `PUT /api/me/inbox/read`; the marker is monotonic, so an older id answers where it already stood.
nonisolated struct InboxReadMarker: Hashable, Codable, Sendable {
    let lastReadId: String
}
