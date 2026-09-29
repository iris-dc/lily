import Foundation

/// The inbox without a backend: the fixture items for whoever is signed in, a read marker kept for the run, and an
/// accept that admits into the group mock's Climbing Buddies, the private group nothing else reaches.
final class MockInboxRepository: InboxRepository {
    private var items: [InboxItem]
    private var lastReadID: String?
    private let groups: MockGroupRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.items = MockInboxFixtures.make(now: now())
        self.groups = groups
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func page(before itemID: String?, limit: Int) async throws -> InboxPage {
        try requireUser()
        let earlier = itemID.map { before in items.filter { $0.id < before } } ?? items
        let page = Array(earlier.suffix(limit))
        let hasMore = earlier.count > limit
        logger.debug(.inbox, "Mock inbox page served (\(page.count) items)")
        return InboxPage(items: page, hasMore: hasMore, nextBefore: hasMore ? page.first?.id : nil, lastReadId: lastReadID)
    }

    /// Monotonic like the backend's; answers where the marker stands.
    func markRead(itemID: String) async throws -> String {
        try requireUser()
        let marker = max(lastReadID ?? "", itemID)
        lastReadID = marker
        return marker
    }

    /// The way into a private group: the group mock admits the caller. A repeat answers the same shape.
    func accept(itemID: String) async throws -> InviteAcceptance {
        try requireUser()
        let (index, invite) = try invite(at: itemID)
        switch invite.status {
        case .declined:
            throw AppError.inviteNotPending
        case .accepted:
            return InviteAcceptance(item: items[index], group: try groups.admit(id: invite.groupId))
        case .pending:
            guard invite.expiresAt > now() else { throw AppError.inviteExpired }
            let group = try groups.admit(id: invite.groupId)
            items[index] = items[index].responding(.accepted, at: now())
            logger.info(.inbox, "Mock invite \(itemID) accepted into group \(group.id)")
            return InviteAcceptance(item: items[index], group: group)
        }
    }

    func decline(itemID: String) async throws -> InboxItem {
        try requireUser()
        let (index, invite) = try invite(at: itemID)
        switch invite.status {
        case .accepted:
            throw AppError.inviteNotPending
        case .declined:
            return items[index]
        case .pending:
            items[index] = items[index].responding(.declined, at: now())
            logger.info(.inbox, "Mock invite \(itemID) declined")
            return items[index]
        }
    }

    /// The invite behind an id; a reminder or an unknown id is nothing to answer (`INBOX_ITEM_NOT_FOUND`).
    private func invite(at itemID: String) throws -> (index: Int, invite: InvitePayload) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), let invite = items[index].invite else {
            throw AppError.inviteNotPending
        }
        return (index, invite)
    }

    /// Like the backend, the inbox is the signed-in user's alone.
    private func requireUser() throws {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
    }
}
