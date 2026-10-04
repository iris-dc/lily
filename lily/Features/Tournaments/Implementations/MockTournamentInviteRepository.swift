import Foundation

/// Invites into a tournament without a backend, behind the same seam as the group invites: the candidates are the
/// people of the caller's communities and the hosts of the mock games minus everyone already in the tournament
/// (`MockInviteCandidatePool`); sent invites are remembered per tournament for the run (`MockInviteLedger`). The
/// refusals follow the backend's: only entrants and the organiser invite, while registration is open, never someone
/// who is in already. Nothing lands in an inbox: the mock user's inbox is the only one there is.
final class MockTournamentInviteRepository: InviteRepository {
    private let ledger = MockInviteLedger()
    private let pool: MockInviteCandidatePool
    private let tournaments: MockTournamentRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository,
         tournaments: MockTournamentRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.tournaments = tournaments
        self.identity = identity
        self.logger = logger
        self.now = now
        pool = MockInviteCandidatePool(groups: groups, now: now)
    }

    func candidates(groupID tournamentID: String) async throws -> [InviteCandidate] {
        let detail = try requireInviteRights(in: tournamentID)
        var seen = peopleIn(detail)
        let candidates = try await pool.candidates(excludingGroup: nil, seen: &seen) { ledger.isInvited($0, into: tournamentID) }
        logger.debug(.tournaments, "Mock invite candidates served for tournament \(tournamentID) (\(candidates.count))")
        return candidates
    }

    /// The backend's refusals in its order: the tournament and the caller's right, the invitee's entry, then whether
    /// the invitee exists at all; a pending invite is replayed.
    func invite(groupID tournamentID: String, userID: String) async throws -> SentInvite {
        let detail = try requireInviteRights(in: tournamentID)
        guard !peopleIn(detail).contains(userID) else { throw AppError.inviteeAlreadyEntered }
        guard let candidate = try await candidates(groupID: tournamentID).first(where: { $0.userId == userID }) else {
            throw AppError.userNotFound
        }
        if let existing = ledger.existing(for: userID, into: tournamentID) {
            logger.info(.tournaments, "Mock invite \(existing.id) replayed for \(userID) in tournament \(tournamentID)")
            return existing
        }
        let invite = ledger.record(candidate, into: .tournament(id: tournamentID), now: now())
        logger.info(.tournaments, "Mock invite \(invite.id) into tournament \(tournamentID) sent to \(userID)")
        return invite
    }

    /// Like the backend: a signed-in entrant or the organiser, while registration is open.
    private func requireInviteRights(in tournamentID: String) throws -> TournamentDetail {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let detail = try tournaments.readable(tournamentID)
        guard tournaments.isInRoom(detail.tournament) else { throw AppError.cannotInviteToTournament }
        guard detail.tournament.isRegistrationOpen(now: now()) else { throw AppError.registrationClosed }
        return detail
    }

    /// Everyone in the tournament as the roster knows them, the organiser and the caller (under both their id and the
    /// fixture's marker) included; none of them is a candidate.
    private func peopleIn(_ detail: TournamentDetail) -> Set<String> {
        var people = Set(detail.entries.flatMap { $0.members.map(\.userId) })
        people.insert(detail.tournament.organizerUserId)
        people.insert(MockTournamentFixtures.callerMarker)
        if let callerID = identity.currentUserID { people.insert(callerID) }
        return people
    }
}
