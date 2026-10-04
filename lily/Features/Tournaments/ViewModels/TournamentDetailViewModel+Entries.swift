import Foundation

/// Entering and leaving from the detail. Every write answers an entry alone, so the detail is fetched again after it:
/// the backend's count and the caller's entry are the authority, and the lists behind learn of the change through
/// `onChange`. Entering and leaving also move the caller's room (the backend joins or leaves it in the same
/// transaction), so Mine is reloaded and the Chats tab lists or drops the room at once, as an accepted invite does. A
/// join also offers the reminder permission, as a join of a game does.
extension TournamentDetailViewModel {
    /// Whether the caller may join this team: an open team tournament they are not in, with room on the team.
    func canJoin(_ entry: TournamentEntry) -> Bool {
        guard participation.offersJoiningATeam, let tournament else { return false }
        return entry.isRegistered && !entry.isFull(teamSize: tournament.teamSize)
    }

    func join() async {
        await enter("Join") { [self] in try await repository.join(id: destination.id, teamName: nil) }
    }

    func createTeam(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        await enter("Create team") { [self] in try await repository.join(id: destination.id, teamName: trimmed) }
    }

    func joinTeam(_ entry: TournamentEntry) async {
        await enter("Join team") { [self] in try await repository.joinTeam(id: destination.id, entryID: entry.id) }
    }

    /// The caller leaves their entry.
    func leave() async {
        guard let entryID = tournament?.myEntryId, let userID = identity.currentUserID else { return }
        await perform("Leave") { [self] in
            _ = try await repository.leave(id: destination.id, entryID: entryID, userID: userID)
            logger.info(.tournaments, "Tournament \(destination.id) left (entry \(entryID))")
            await refetch()
            await myGroups.reload()
            // Mine is read from an index that may still list the room for a moment; an organiser keeps theirs.
            if !role.isOrganizer { myGroups.remove(id: destination.id) }
        }
    }

    /// The organiser drops a whole entry while registration is open.
    func removeEntry(_ entry: TournamentEntry) async {
        await perform("Remove entry") { [self] in
            try await repository.removeEntry(id: destination.id, entryID: entry.id)
            logger.info(.tournaments, "Tournament \(destination.id): entry \(entry.id) removed")
            await refetch()
        }
    }

    private func enter(_ action: String, _ write: () async throws -> TournamentEntry) async {
        await perform(action) { [self] in
            let entry = try await write()
            logger.info(.tournaments, "Tournament \(destination.id) joined as entry \(entry.id)")
            await refetch()
            await myGroups.reload()
            await pushOptIn.offerReminders()
        }
    }

    /// The detail as the backend now holds it, handed on to the lists; a failed refetch keeps the popup for the write
    /// that did land, so nothing is reported twice.
    private func refetch() async {
        guard let fresh = try? await repository.tournament(id: destination.id) else {
            logger.warning(.tournaments, "Could not refresh tournament \(destination.id) after a write")
            return
        }
        accept(fresh)
    }
}
