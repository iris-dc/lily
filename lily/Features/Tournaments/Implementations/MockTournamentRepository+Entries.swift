import Foundation

/// Entering and leaving: the rules of the backend's entry transactions, in memory, with the refusals read in the order
/// the backend reads them (the entry's before the root's, who may act before the registration window). Every write that
/// puts a player in or takes them out moves the room's roster in the group mock the same way.
extension MockTournamentRepository {
    func join(id: String, teamName: String?) async throws -> TournamentEntry {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let detail = try readable(id)
        try requireEnterable(detail)
        let tournament = detail.tournament
        guard !tournament.isFull else { throw AppError.tournamentFull }
        let name = teamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if tournament.isTeam, TeamNameIssue.issue(in: name) != nil { throw AppError.tournamentActionFailed }
        let caller = MockTournamentFixtures.callerMarker
        let member = EntryMember(userId: caller, displayName: AppBranding.Tournaments.Create.mockOrganizerName)
        entrySequence += 1
        let entry = TournamentEntry(id: nextEntryID(in: id),
                                    tournamentId: id,
                                    name: tournament.isTeam ? name : member.displayName,
                                    captainUserId: caller,
                                    members: [member],
                                    seed: (detail.entries.map(\.seed).max() ?? 0) + 1,
                                    createdAt: now())
        let updated = detail.replacing(entries: detail.entries + [entry])
            .replacing(tournament: tournament.updatingEntries(count: tournament.entryCount + 1, myEntryId: entry.id, at: now()))
        enter(updated, logging: "Tournament \(id) joined as entry \(entry.id)")
        return entry.replacingUser(caller, with: identity.currentUserID)
    }

    /// The team's refusals come first (gone, the caller in it, full), then the tournament's (registration over, the
    /// caller in another entry), as the backend's transaction reads them.
    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry {
        guard identity.currentUserID != nil else { throw AppError.sessionExpired }
        let detail = try readable(id)
        guard let index = detail.entries.firstIndex(where: { $0.id == entryID }) else { throw AppError.entryNotFound }
        let caller = MockTournamentFixtures.callerMarker
        guard !detail.entries[index].contains(userID: caller) else { throw AppError.alreadyEntered }
        guard !detail.entries[index].isFull(teamSize: detail.tournament.teamSize) else { throw AppError.teamFull }
        try requireEnterable(detail)
        let member = EntryMember(userId: caller, displayName: AppBranding.Tournaments.Create.mockOrganizerName)
        var entries = detail.entries
        entries[index] = entries[index].adding(member)
        let updated = detail.replacing(entries: entries)
            .replacing(tournament: detail.tournament.updatingEntries(count: detail.tournament.entryCount,
                                                                     myEntryId: entryID,
                                                                     at: now()))
        enter(updated, logging: "Tournament \(id) joined team \(entryID)")
        return entries[index].replacingUser(caller, with: identity.currentUserID)
    }

    /// The player themselves, their captain or the organiser, judged before the registration window as the backend
    /// judges it; an emptied entry is deleted and the count drops.
    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry? {
        let detail = try readable(id)
        guard let index = detail.entries.firstIndex(where: { $0.id == entryID }) else { throw AppError.entryNotFound }
        let entry = detail.entries[index]
        let caller = MockTournamentFixtures.callerMarker
        let target = userID == identity.currentUserID ? caller : userID
        guard target == caller || entry.isCaptain(caller) || detail.tournament.organizerUserId == caller else {
            throw AppError.insufficientRole
        }
        guard detail.tournament.status == .registration else { throw AppError.registrationClosed }
        guard entry.contains(userID: target) else { throw AppError.entryNotFound }
        var entries = detail.entries
        let remaining = entry.removing(userID: target)
        if let remaining { entries[index] = remaining } else { entries.remove(at: index) }
        let count = detail.tournament.entryCount - (remaining == nil ? 1 : 0)
        let myEntryId = target == caller ? nil : detail.tournament.myEntryId
        let updated = detail.replacing(entries: entries)
            .replacing(tournament: detail.tournament.updatingEntries(count: count, myEntryId: myEntryId, at: now()))
        let verb = target == caller ? "left" : "removed \(userID) from"
        depart(updated, userID: target, logging: "Tournament \(id): \(verb) entry \(entryID)")
        return remaining?.replacingUser(caller, with: identity.currentUserID)
    }

    /// The organiser drops a whole entry while registration is open; every member leaves the room.
    func removeEntry(id: String, entryID: String) async throws {
        let detail = try organized(id)
        guard let entry = detail.entry(id: entryID) else { throw AppError.entryNotFound }
        guard detail.tournament.status == .registration else { throw AppError.registrationClosed }
        let entries = detail.entries.filter { $0.id != entryID }
        let caller = MockTournamentFixtures.callerMarker
        let myEntryId = entry.contains(userID: caller) ? nil : detail.tournament.myEntryId
        let updated = detail.replacing(entries: entries)
            .replacing(tournament: detail.tournament.updatingEntries(count: entries.count, myEntryId: myEntryId, at: now()))
        for member in entry.members {
            depart(updated, userID: member.userId, logging: "Tournament \(id): entry \(entryID) removed by the organiser")
        }
    }

    /// The root's conditions on an entering write: registration open (status and deadline) and the caller not in yet.
    private func requireEnterable(_ detail: TournamentDetail) throws {
        guard detail.tournament.isRegistrationOpen(now: now()) else { throw AppError.registrationClosed }
        guard detail.entry(containing: MockTournamentFixtures.callerMarker) == nil else { throw AppError.alreadyEntered }
    }

    private func enter(_ detail: TournamentDetail, logging message: String) {
        store(detail)
        groups.admitToRoom(id: detail.id)
        groups.syncRoom(for: detail.tournament, memberCount: MockTournamentFixtures.playerCount(of: detail))
        logger.info(.tournaments, message)
    }

    private func depart(_ detail: TournamentDetail, userID: String, logging message: String) {
        store(detail)
        groups.leaveRoom(id: detail.id, userID: userID == MockTournamentFixtures.callerMarker ? nil : userID)
        groups.syncRoom(for: detail.tournament, memberCount: MockTournamentFixtures.playerCount(of: detail))
        logger.info(.tournaments, message)
    }

    private func nextEntryID(in tournamentID: String) -> String {
        MockTournamentFixtures.entryID(tournamentID: tournamentID, index: 100 + entrySequence)
    }
}
