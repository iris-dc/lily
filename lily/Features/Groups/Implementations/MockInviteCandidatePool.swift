import Foundation

/// The people a mock invite may go to, sifted the way the backend sifts them: the live members of the caller's groups
/// and rooms (each with the first group they share) and the hosts of the mock games (under the ids the rosters use for
/// the same names, so one person is one candidate). Shared by the group and the tournament invite mocks.
struct MockInviteCandidatePool {
    let groups: MockGroupRepository
    let now: () -> Date

    /// Everyone not in `seen`, by name; `seen` grows with every candidate taken, and `isInvited` answers per target.
    func candidates(excludingGroup groupID: String?,
                    seen: inout Set<String>,
                    isInvited: (String) -> Bool) async throws -> [InviteCandidate] {
        var candidates = try await groupCandidates(excludingGroup: groupID, seen: &seen, isInvited: isInvited)
        candidates += eventCandidates(seen: &seen, isInvited: isInvited)
        return candidates.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Every live member of the caller's groups and tournament rooms but the one invited into, each with the first
    /// group they share; a direct conversation is the one membership that yields nobody, as on the backend.
    private func groupCandidates(excludingGroup groupID: String?,
                                 seen: inout Set<String>,
                                 isInvited: (String) -> Bool) async throws -> [InviteCandidate] {
        var candidates: [InviteCandidate] = []
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items
        for group in mine where group.id != groupID && !group.isDirect {
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

    /// The one send behind both invite mocks, after their own refusals: `userID` must be among `candidates` (else
    /// `.userNotFound`, the backend's answer for someone the caller does not know), a pending invite into `target` is
    /// replayed, otherwise a new one is recorded; the log lines carry ids only.
    func send(to userID: String,
              among candidates: [InviteCandidate],
              into target: InviteTarget,
              now: Date,
              logger: any Logging) throws -> SentInvite {
        guard let candidate = candidates.first(where: { $0.userId == userID }) else { throw AppError.userNotFound }
        if let existing = existing(for: userID, into: target.id) {
            logger.info(target.logCategory, "Mock invite \(existing.id) replayed for \(userID) in \(target.logName)")
            return existing
        }
        let invite = record(candidate, into: target, now: now)
        logger.info(target.logCategory, "Mock invite \(invite.id) into \(target.logName) sent to \(userID)")
        return invite
    }

    private func existing(for userID: String, into targetID: String) -> SentInvite? {
        sent[targetID]?[userID]
    }

    /// A new invite into `target` for the candidate, dated `now` and expiring a mock week later.
    private func record(_ candidate: InviteCandidate, into target: InviteTarget, now: Date) -> SentInvite {
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
