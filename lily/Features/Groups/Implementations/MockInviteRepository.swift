import Foundation

/// Direct invites without a backend: the candidates are the people on the rosters of the caller's other mock groups
/// and tournament rooms and the hosts of the mock games, minus the target group's own roster
/// (`MockInviteCandidatePool`). Sent invites are remembered per group for the run (`MockInviteLedger`), so `isInvited`
/// follows and a repeat answers the same invite. Nothing lands in an inbox: the mock user's inbox is the only one
/// there is.
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
        let candidates = try await self.candidates(in: groupID)
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
        let candidates = try await self.candidates(in: groupID)
        return try ledger.send(to: userID, among: candidates, into: .group(id: groupID), now: now(), logger: logger)
    }

    /// The pool minus the group's roster and the caller, for a caller whose rights were checked.
    private func candidates(in groupID: String) async throws -> [InviteCandidate] {
        var seen = Set(groups.roster(of: groupID).map(\.userId))
        if let callerID = identity.currentUserID { seen.insert(callerID) }
        return try await pool.candidates(excludingGroup: groupID, seen: &seen) { ledger.isInvited($0, into: groupID) }
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
