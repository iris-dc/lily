import Foundation

/// Direct invites without a backend: the candidates are the people on the rosters of the caller's other mock groups
/// and the hosts of the mock games, minus the target group's own roster, sifted the way the backend does. Sent
/// invites are remembered per group for the run, so `isInvited` follows and a repeat answers the same invite. Nothing
/// lands in an inbox: the mock user's inbox is the only one there is.
final class MockInviteRepository: InviteRepository {
    /// Sent invites by group id, then invitee id.
    private var sent: [String: [String: SentInvite]] = [:]
    private var sentCount = 0
    private let groups: MockGroupRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date
    private static let idPrefix = "01J8MOCKIV"
    private static let idDigits = 16

    init(groups: MockGroupRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.groups = groups
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func candidates(groupID: String) async throws -> [InviteCandidate] {
        try await requireInviteRights(in: groupID)
        var seen = Set(groups.roster(of: groupID).map(\.userId))
        if let callerID = identity.currentUserID { seen.insert(callerID) }
        var candidates = try await groupCandidates(for: groupID, seen: &seen)
        candidates += eventCandidates(for: groupID, seen: &seen)
        logger.debug(.groups, "Mock invite candidates served for group \(groupID) (\(candidates.count))")
        return candidates.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
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
        if let existing = sent[groupID]?[userID] {
            logger.info(.groups, "Mock invite \(existing.id) replayed for \(userID) in group \(groupID)")
            return existing
        }
        let invite = makeInvite(groupID: groupID, candidate: candidate)
        sent[groupID, default: [:]][userID] = invite
        logger.info(.groups, "Mock invite \(invite.id) into group \(groupID) sent to \(userID)")
        return invite
    }

    /// Every live member of the caller's other groups, each with the first group they share.
    private func groupCandidates(for groupID: String, seen: inout Set<String>) async throws -> [InviteCandidate] {
        var candidates: [InviteCandidate] = []
        for group in try await groups.groups(in: .mine, cursor: nil).items where group.id != groupID {
            for member in groups.roster(of: group.id) where member.role != .banned && !seen.contains(member.userId) {
                seen.insert(member.userId)
                candidates.append(InviteCandidate(userId: member.userId,
                                                  displayName: member.displayName,
                                                  via: .group,
                                                  viaName: group.name,
                                                  isInvited: isInvited(member.userId, in: groupID)))
            }
        }
        return candidates
    }

    /// The hosts of the mock games, under the ids the rosters use for the same names, so one person is one candidate.
    private func eventCandidates(for groupID: String, seen: inout Set<String>) -> [InviteCandidate] {
        var candidates: [InviteCandidate] = []
        for event in MockEventFixtures.make(now: now(), count: AppConfig.Events.mockFeedSize) {
            let hostID = MockGroupFixtures.memberID(for: event.hostName)
            guard !seen.contains(hostID) else { continue }
            seen.insert(hostID)
            candidates.append(InviteCandidate(userId: hostID,
                                              displayName: event.hostName,
                                              via: .event,
                                              viaName: event.title,
                                              isInvited: isInvited(hostID, in: groupID)))
        }
        return candidates
    }

    private func isInvited(_ userID: String, in groupID: String) -> Bool {
        sent[groupID]?[userID] != nil
    }

    private func makeInvite(groupID: String, candidate: InviteCandidate) -> SentInvite {
        sentCount += 1
        let created = now()
        return SentInvite(id: Self.idPrefix + String(format: "%0\(Self.idDigits)d", sentCount),
                          groupId: groupID,
                          inviteeUserId: candidate.userId,
                          inviteeName: candidate.displayName,
                          status: .pending,
                          createdAt: created,
                          expiresAt: created.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry))
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
