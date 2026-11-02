import Foundation

/// Entering and leaving: the rules of the backend's entry transactions, in memory, with the refusals read in the order
/// the backend reads them (the entry's before the root's, who may act before the registration window). Every write that
/// puts a player in or takes them out moves the room's roster in the group mock the same way.
extension MockTournamentRepository {
    /// A team's name is judged first, as the backend validates the body before counting the caller's rooms; then the
    /// caller's cap, then the root's conditions.
    func join(id: String, teamName: String?) async throws -> TournamentEntry {
        try requireCaller()
        let detail = try readable(id)
        let tournament = detail.tournament
        let name = teamName.trimmed
        if tournament.isTeam, TeamNameIssue.issue(in: name) != nil { throw AppError.tournamentActionFailed }
        try requireRoomSlot(detail)
        try requireEnterable(detail)
        guard !tournament.isFull else { throw AppError.tournamentFull }
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
        let updated = counting(detail.replacing(entries: detail.entries + [entry]), entries: tournament.entryCount + 1)
        enter(updated, logging: "Tournament \(id) joined as entry \(entry.id)")
        return entry.replacingUser(caller, with: identity.currentUserID)
    }

    /// The caller's cap is judged first, then the team's refusals (gone, the caller in it, full), then the tournament's
    /// (registration over, the caller in another entry), as the backend's transaction reads them.
    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry {
        try requireCaller()
        let detail = try readable(id)
        try requireRoomSlot(detail)
        guard let index = detail.entries.firstIndex(where: { $0.id == entryID }) else { throw AppError.entryNotFound }
        let caller = MockTournamentFixtures.callerMarker
        guard !detail.entries[index].contains(userID: caller) else { throw AppError.alreadyEntered }
        guard !detail.entries[index].isFull(teamSize: detail.tournament.teamSize) else { throw AppError.teamFull }
        try requireEnterable(detail)
        let member = EntryMember(userId: caller, displayName: AppBranding.Tournaments.Create.mockOrganizerName)
        var entries = detail.entries
        entries[index] = entries[index].adding(member)
        let updated = counting(detail.replacing(entries: entries), entries: detail.tournament.entryCount)
        enter(updated, logging: "Tournament \(id) joined team \(entryID)")
        return entries[index].replacingUser(caller, with: identity.currentUserID)
    }

    /// The player themselves, their captain or the organiser, judged before the registration window as the backend
    /// judges it; an emptied entry is deleted and the count drops.
    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry? {
        try requireCaller()
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
        let updated = counting(detail.replacing(entries: entries),
                               entries: count,
                               departed: target != detail.tournament.organizerUserId)
        let verb = target == caller ? "left" : "removed \(userID) from"
        depart(updated, userIDs: [target], logging: "Tournament \(id): \(verb) entry \(entryID)")
        return remaining?.replacingUser(caller, with: identity.currentUserID)
    }

    /// The organiser drops a whole entry while registration is open; every member leaves the room.
    func removeEntry(id: String, entryID: String) async throws {
        let detail = try organized(id)
        guard let entry = detail.entry(id: entryID) else { throw AppError.entryNotFound }
        guard detail.tournament.status == .registration else { throw AppError.registrationClosed }
        let entries = detail.entries.filter { $0.id != entryID }
        let updated = counting(detail.replacing(entries: entries),
                               entries: entries.count,
                               departed: entry.members.contains { $0.userId != detail.tournament.organizerUserId })
        depart(updated,
               userIDs: entry.members.map(\.userId),
               logging: "Tournament \(id): entry \(entryID) removed by the organiser")
    }

    /// The open tournaments whose room the caller is in, organiser or player, against `AppConfig.Tournaments.maxPerUser`.
    var openInRoomsCount: Int {
        details.values.filter { isInRoom($0.tournament) && Self.isOpen($0.tournament) }.count
    }

    /// The backend's cap on open tournaments per user, judged before the room's own conditions; a caller with a row in
    /// this room already (the organiser, or a repeat whose answer was lost) is let through to those conditions.
    private func requireRoomSlot(_ detail: TournamentDetail) throws {
        guard !isInRoom(detail.tournament) else { return }
        guard openInRoomsCount < AppConfig.Tournaments.maxPerUser else { throw AppError.tournamentMembershipLimit }
    }

    /// The root's conditions on an entering write: registration open (status and deadline) and the caller not in yet.
    private func requireEnterable(_ detail: TournamentDetail) throws {
        guard detail.tournament.isRegistrationOpen(now: now()) else { throw AppError.registrationClosed }
        guard detail.entry(containing: MockTournamentFixtures.callerMarker) == nil else { throw AppError.alreadyEntered }
    }

    /// The root after an entry write. `myEntryId` stays nil: `resolved` recomputes it from the roster on the way out,
    /// so a swapped mock sign-in reads its own. The epoch moves once per departure of anyone but the organiser, as the
    /// backend bumps room and root in that transaction (the organiser stays in the room, so their entry moves nothing).
    private func counting(_ detail: TournamentDetail, entries count: Int, departed: Bool = false) -> TournamentDetail {
        let tournament = detail.tournament
        return detail.replacing(tournament: tournament.updatingEntries(count: count,
                                                                       myEntryId: nil,
                                                                       channelEpoch: departed ? tournament.channelEpoch + 1 : nil,
                                                                       at: now()))
    }

    private func enter(_ detail: TournamentDetail, logging message: String) {
        store(detail)
        groups.admitToRoom(id: detail.id)
        groups.syncRoom(for: detail.tournament, memberCount: MockTournamentFixtures.playerCount(of: detail))
        logger.info(.tournaments, message)
    }

    private func depart(_ detail: TournamentDetail, userIDs: [String], logging message: String) {
        store(detail)
        for userID in userIDs {
            groups.leaveRoom(id: detail.id, userID: userID == MockTournamentFixtures.callerMarker ? nil : userID)
        }
        groups.syncRoom(for: detail.tournament, memberCount: MockTournamentFixtures.playerCount(of: detail))
        logger.info(.tournaments, message)
    }

    private func nextEntryID(in tournamentID: String) -> String {
        MockTournamentFixtures.entryID(tournamentID: tournamentID, index: 100 + entrySequence)
    }
}
