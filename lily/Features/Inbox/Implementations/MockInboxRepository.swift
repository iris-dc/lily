import Foundation

/// The inbox without a backend: the fixture items for whoever is signed in, a read marker kept for the run, and an
/// accept that admits into the group mock's Climbing Buddies, enters the tournament mock's Padel Open (the private
/// group and tournament nothing else reaches) or joins the event mock's game. Under `-mock-deleted-user` the two
/// deletion notices join the fixtures.
final class MockInboxRepository: InboxRepository {
    private var items: [InboxItem]
    private var lastReadID: String?
    private let groups: MockGroupRepository
    private let tournaments: MockTournamentRepository
    private let events: MockEventRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository,
         tournaments: MockTournamentRepository,
         events: MockEventRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         deletedUser: Bool = false,
         now: @escaping () -> Date = { .now }) {
        var items = MockInboxFixtures.make(now: now())
        if deletedUser { items += MockInboxFixtures.deletionNotices(now: now()) }
        // The deletion notices' ids predate the event invite's; the page contract is ascending by id.
        self.items = items.sorted { $0.id < $1.id }
        self.groups = groups
        self.tournaments = tournaments
        self.events = events
        self.identity = identity
        self.logger = logger
        self.now = now
        for invite in items.compactMap(\.tournamentInvite) where invite.status == .pending {
            tournaments.noteInvitee(of: invite.tournamentId)
        }
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

    /// The way into a private group, a tournament or a game: the group mock admits the caller, the tournament mock
    /// enters them (an individual tournament; a team one is left for the detail), or the event mock joins the game,
    /// so the room follows. The entry comes first, so a refused one leaves the item pending, as the backend's
    /// transaction does. A repeat answers the same shape.
    func accept(itemID: String) async throws -> InviteAcceptance {
        try requireUser()
        let (index, answer) = try invite(at: itemID)
        switch answer.status {
        case .declined, .unknown:
            throw AppError.inviteNotPending
        case .accepted:
            return try await admittance(for: items[index], entering: false)
        case .pending:
            guard answer.isOpen(now: now()) else { throw AppError.inviteExpired }
            let admitted = try await admittance(for: items[index], entering: true)
            items[index] = items[index].responding(.accepted, at: now())
            return InviteAcceptance(item: items[index],
                                    group: admitted.group,
                                    tournament: admitted.tournament,
                                    event: admitted.event)
        }
    }

    func decline(itemID: String) async throws -> InboxItem {
        try requireUser()
        let (index, answer) = try invite(at: itemID)
        switch answer.status {
        case .accepted, .unknown:
            throw AppError.inviteNotPending
        case .declined:
            return items[index]
        case .pending:
            items[index] = items[index].responding(.declined, at: now())
            logger.info(.inbox, "Mock invite \(itemID) declined")
            return items[index]
        }
    }

    /// What the invite lets the caller into; `entering` is false on a replay, which enters nobody twice.
    private func admittance(for item: InboxItem, entering: Bool) async throws -> InviteAcceptance {
        if let invite = item.invite {
            let group = try groups.admit(id: invite.groupId)
            if entering { logger.info(.inbox, "Mock invite \(item.id) accepted into group \(group.id)") }
            return InviteAcceptance(item: item, group: group)
        }
        if let invite = item.eventInvite {
            let current = try await events.event(id: invite.eventId)
            guard entering else { return InviteAcceptance(item: item, event: current) }
            let joined = if current.participates { current } else { try await events.join(eventId: invite.eventId) }
            logger.info(.inbox, "Mock invite \(item.id) accepted into event \(invite.eventId)")
            return InviteAcceptance(item: item, event: joined)
        }
        guard let invite = item.tournamentInvite else { throw AppError.inviteNotPending }
        if entering, !invite.isTeam {
            _ = try await tournaments.join(id: invite.tournamentId, teamName: nil)
        }
        if entering { logger.info(.inbox, "Mock invite \(item.id) accepted into tournament \(invite.tournamentId)") }
        return InviteAcceptance(item: item, tournament: try tournaments.invited(invite.tournamentId))
    }

    /// The invite behind an id; a reminder or an unknown id is nothing to answer (`INBOX_ITEM_NOT_FOUND`).
    private func invite(at itemID: String) throws -> (index: Int, answer: any InviteAnswer) {
        guard let index = items.firstIndex(where: { $0.id == itemID }), let answer = items[index].inviteAnswer else {
            throw AppError.inviteNotPending
        }
        return (index, answer)
    }

    /// Like the backend, the inbox is the signed-in user's alone.
    private func requireUser() throws {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
    }
}
