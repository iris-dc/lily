import Foundation

/// Invites into an event without a backend, behind the same seam as the group invites: the candidates are the people
/// of the caller's groups and rooms and the hosts of the mock games minus everyone already in the event
/// (`MockInviteCandidatePool`); sent invites are remembered per event for the run (`MockInviteLedger`). The refusals
/// follow the backend's: only the host and participants invite, while the event has not started, never someone who is
/// in already. Nothing lands in an inbox: the mock user's inbox is the only one there is.
final class MockEventInviteRepository: InviteRepository {
    private let ledger = MockInviteLedger()
    private let pool: MockInviteCandidatePool
    private let events: MockEventRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository,
         events: MockEventRepository,
         identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.events = events
        self.identity = identity
        self.logger = logger
        self.now = now
        pool = MockInviteCandidatePool(groups: groups, now: now)
    }

    func candidates(groupID eventID: String) async throws -> [InviteCandidate] {
        let event = try requireInviteRights(in: eventID)
        let candidates = try await self.candidates(for: event)
        logger.debug(.events, "Mock invite candidates served for event \(eventID) (\(candidates.count))")
        return candidates
    }

    /// The backend's refusals in its order: the event and the caller's right, the invitee's participation, then
    /// whether the invitee exists at all; a pending invite is replayed.
    func invite(groupID eventID: String, userID: String) async throws -> SentInvite {
        let event = try requireInviteRights(in: eventID)
        guard try await !peopleIn(event).contains(userID) else { throw AppError.inviteeAlreadyJoined }
        let candidates = try await self.candidates(for: event)
        return try ledger.send(to: userID, among: candidates, into: .event(id: eventID), now: now(), logger: logger)
    }

    /// The pool minus everyone in the event, for a caller whose right was checked.
    private func candidates(for event: SportEvent) async throws -> [InviteCandidate] {
        var seen = try await peopleIn(event)
        // The event's own room (under its id) is left out, as the backend leaves the target out of the pool.
        return try await pool.candidates(excludingGroup: event.id, seen: &seen) {
            ledger.isInvited($0, into: event.id)
        }
    }

    /// Like the backend: the signed-in host or a participant, while the event has not started.
    private func requireInviteRights(in eventID: String) throws -> SportEvent {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let event = try events.stored(eventID)
        guard event.participates || event.isHosted(by: identity.currentUserID) else { throw AppError.cannotInviteToEvent }
        guard event.startsAt > now() else { throw AppError.eventStarted }
        return event
    }

    /// Everyone in the event as its roster knows them, the caller included; none of them is a candidate.
    private func peopleIn(_ event: SportEvent) async throws -> Set<String> {
        var people = Set(try await events.participants(eventId: event.id).map(\.userId))
        if let callerID = identity.currentUserID { people.insert(callerID) }
        return people
    }
}
