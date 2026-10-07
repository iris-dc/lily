import Foundation

/// The people a mock invite may go to, sifted the way the backend sifts them: the live members of the caller's
/// communities (each with the first community they share) and the hosts of the mock games (under the ids the rosters
/// use for the same names, so one person is one candidate). Shared by the group and the tournament invite mocks.
struct MockInviteCandidatePool {
    let groups: MockGroupRepository
    let now: () -> Date

    /// Everyone not in `seen`, by name; `seen` grows with every candidate taken, and `isInvited` answers per target.
    func candidates(excludingGroup groupID: String?,
                    seen: inout Set<String>,
                    isInvited: (String) -> Bool) async throws -> [InviteCandidate] {
        var candidates = try await communityCandidates(excludingGroup: groupID, seen: &seen, isInvited: isInvited)
        candidates += eventCandidates(seen: &seen, isInvited: isInvited)
        return candidates.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Every live member of the caller's communities but the one invited into, each with the first group they share.
    /// A direct conversation or a tournament's room is no shared group: their people come in through a community or a
    /// game, or not at all, as on the backend.
    private func communityCandidates(excludingGroup groupID: String?,
                                     seen: inout Set<String>,
                                     isInvited: (String) -> Bool) async throws -> [InviteCandidate] {
        var candidates: [InviteCandidate] = []
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items
        for group in mine where group.id != groupID && group.isCommunity {
            for member in groups.roster(of: group.id) where member.role != .banned && !seen.contains(member.userId) {
                seen.insert(member.userId)
                candidates.append(InviteCandidate(userId: member.userId,
                                                  displayName: member.displayName,
                                                  via: .group,
                                                  viaName: group.name,
                                                  isInvited: isInvited(member.userId)))
            }
        }
        return candidates
    }

    private func eventCandidates(seen: inout Set<String>, isInvited: (String) -> Bool) -> [InviteCandidate] {
        var candidates: [InviteCandidate] = []
        for event in MockEventFixtures.make(now: now(), count: AppConfig.Events.mockFeedSize) {
            let hostID = MockGroupFixtures.memberID(for: event.hostName)
            guard !seen.contains(hostID) else { continue }
            seen.insert(hostID)
            candidates.append(InviteCandidate(userId: hostID,
                                              displayName: event.hostName,
                                              via: .event,
                                              viaName: event.title,
                                              isInvited: isInvited(hostID)))
        }
        return candidates
    }
}

/// The invites a mock sent, per target and invitee, for the run: `isInvited` follows them and a repeat answers the
/// same invite, as the backend replays a pending one.
final class MockInviteLedger {
    private var sent: [String: [String: SentInvite]] = [:]
    private var sentCount = 0
    private static let idPrefix = "01J8MOCKIV"
    private static let idDigits = 16

    func isInvited(_ userID: String, into targetID: String) -> Bool {
        sent[targetID]?[userID] != nil
    }

    func existing(for userID: String, into targetID: String) -> SentInvite? {
        sent[targetID]?[userID]
    }

    /// A new invite into `target` for the candidate, dated `now` and expiring a mock week later.
    func record(_ candidate: InviteCandidate, into target: InviteTarget, now: Date) -> SentInvite {
        sentCount += 1
        let groupID: String? = if case .group(let id) = target { id } else { nil }
        let tournamentID: String? = if case .tournament(let id) = target { id } else { nil }
        let invite = SentInvite(id: Self.idPrefix + String(format: "%0\(Self.idDigits)d", sentCount),
                                groupId: groupID,
                                tournamentId: tournamentID,
                                inviteeUserId: candidate.userId,
                                inviteeName: candidate.displayName,
                                status: .pending,
                                createdAt: now,
                                expiresAt: now.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry))
        sent[target.id, default: [:]][candidate.userId] = invite
        return invite
    }
}
