import Foundation

/// Direct invites without a backend: the candidates are the people on the rosters of the caller's other mock groups
/// and the hosts of the mock games, minus the target group's own roster (`MockInviteCandidatePool`). Sent invites are
/// remembered per group for the run (`MockInviteLedger`), so `isInvited` follows and a repeat answers the same invite.
/// Nothing lands in an inbox: the mock user's inbox is the only one there is.
final class MockInviteRepository: InviteRepository {
    private let ledger = MockInviteLedger()
    private let pool: MockInviteCandidatePool
    private let groups: MockGroupRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.groups = groups
        self.identity = identity
        self.logger = logger
        self.now = now
        pool = MockInviteCandidatePool(groups: groups, now: now)
    }

    func candidates(groupID: String) async throws -> [InviteCandidate] {
        try await requireInviteRights(in: groupID)
        var seen = Set(groups.roster(of: groupID).map(\.userId))
        if let callerID = identity.currentUserID { seen.insert(callerID) }
        let candidates = try await pool.candidates(excludingGroup: groupID, seen: &seen) { ledger.isInvited($0, into: groupID) }
        logger.debug(.groups, "Mock invite candidates served for group \(groupID) (\(candidates.count))")
        return candidates
    }

    /// The backend's refusals in its order: the group and the caller's rights, the target's row in the group, then
    /// whether the target exists at all; a pending invite is replayed.
    func invite(groupID: String, userID: String) async throws -> SentInvite {
        try await requireInviteRights(in: groupID)
        guard userID != identity.currentUserID else { throw AppError.alreadyMember }
        if let row = groups.roster(of: groupID).first(where: { $0.userId == userID }) {
            throw row.role == .banned ? AppError.cannotInvite : AppError.alreadyMember
        }
        guard let candidate = try await candidates(groupID: groupID).first(where: { $0.userId == userID }) else {
            throw AppError.userNotFound
        }
        if let existing = ledger.existing(for: userID, into: groupID) {
            logger.info(.groups, "Mock invite \(existing.id) replayed for \(userID) in group \(groupID)")
            return existing
        }
        let invite = ledger.record(candidate, into: .group(id: groupID), now: now())
        logger.info(.groups, "Mock invite \(invite.id) into group \(groupID) sent to \(userID)")
        return invite
    }

    /// Like the backend: a signed-in member with invite rights, in a group they can see.
    private func requireInviteRights(in groupID: String) async throws {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let group = try await groups.group(id: groupID)
        let access = GroupAccess(group: group, userID: identity.currentUserID)
        guard access.canChat else { throw AppError.notAMember }
        guard access.canInvite(in: group) else { throw AppError.insufficientRole }
    }
}
