import Foundation

/// Entering and leaving from the detail. Every write answers an entry alone, so the detail is fetched again
/// (`load(reportingFailures: false)`): the backend's count and the caller's entry are the authority. The backend moves
/// the caller's room in the same transaction, so Mine is reloaded and the Chats tab lists or drops the room at once. A
/// write whose answer was lost, and a refusal a stale detail earned, read the detail back (`LostAnswer`) so the control
/// and the popup agree with the backend; a landed write reports nothing.
extension TournamentDetailViewModel {
    /// Whether the caller may join this team: they may still enter and the team has a seat. A full tournament is no bar:
    /// joining a team adds no entry, and the backend's `joinTeamRoot` checks registration and not-entered only.
    func canJoin(_ entry: TournamentEntry) -> Bool {
        guard permissions.canJoinTeams, let tournament else { return false }
        return entry.isRegistered && !entry.isFull(teamSize: tournament.teamSize)
    }

    func join() async {
        await enter("Join") { [self] in try await repository.join(id: destination.id, teamName: nil) }
    }

    /// Answers whether the caller's team exists now, by the write's answer or the read-back, so the sheet closes on it.
    /// `onEntered` runs as soon as it does, before Mine reloads and the reminders are offered, so the sheet is gone
    /// when the system prompt comes up.
    @discardableResult
    func createTeam(named name: String, onEntered: () -> Void = {}) async -> Bool {
        let trimmed = name.trimmed
        return await enter("Create team", onEntered: onEntered) { [self] in
            try await repository.join(id: destination.id, teamName: trimmed)
        }
    }

    func joinTeam(_ entry: TournamentEntry) async {
        await enter("Join team") { [self] in try await repository.joinTeam(id: destination.id, entryID: entry.id) }
    }

    /// The caller leaves their entry.
    func leave() async {
        guard let entryID = tournament?.myEntryId, let userID = identity.currentUserID else { return }
        let left = await settleEntry("Leave",
                                     writing: { [self] in
                                         _ = try await repository.leave(id: destination.id, entryID: entryID, userID: userID)
                                         logger.info(.tournaments, "Tournament \(destination.id) left (entry \(entryID))")
                                     },
                                     landedWhen: { !$0.tournament.hasEntered })
        guard left else { return }
        await myGroups.reload()
        // Mine is read from an index that may still list the room for a moment; an organiser keeps theirs.
        if !role.isOrganizer { myGroups.remove(id: destination.id) }
    }

    /// The organiser drops a whole entry while registration is open; the room moves for the entrants, not the caller.
    func removeEntry(_ entry: TournamentEntry) async {
        await settleEntry("Remove entry",
                          writing: { [self] in
                              try await repository.removeEntry(id: destination.id, entryID: entry.id)
                              logger.info(.tournaments, "Tournament \(destination.id): entry \(entry.id) removed")
                          },
                          landedWhen: { $0.entry(id: entry.id) == nil })
    }

    @discardableResult
    private func enter(_ action: String,
                       onEntered: () -> Void = {},
                       _ write: () async throws -> TournamentEntry) async -> Bool {
        let entered = await settleEntry(action,
                                        writing: { [self] in
                                            let entry = try await write()
                                            logger.info(.tournaments, "Tournament \(destination.id) joined as entry \(entry.id)")
                                        },
                                        landedWhen: { $0.tournament.hasEntered })
        guard entered else { return false }
        onEntered()
        await myGroups.reload()
        // Outside the gate, so Join is not left spinning behind the system prompt through the token wait and the device POST.
        await pushOptIn.offerReminders()
        return true
    }

    /// One entry write through the gate: the detail is fetched again after an answer, and read back after a lost one
    /// or a refusal; `intent` reads the fresh detail for what the write wanted. Answers whether the write landed.
    @discardableResult
    private func settleEntry(_ action: String,
                             writing write: () async throws -> Void,
                             landedWhen intent: (TournamentDetail) -> Bool) async -> Bool {
        let what = "\(action) for tournament \(destination.id)"
        return await perform(action,
                             settling: { [self] error in
                                 await entryReadBack.settle(what, despite: error) { intent($0) }.isLanded
                             },
                             { [self] in
                                 try await write()
                                 await load(reportingFailures: false)
                             })
    }

    /// The detail is the authority on entries, so it is read back and shown after a lost answer and after the refusals a
    /// stale detail earns, except the ones no fresh detail explains (`.termsRequired`, a second `.tryAgain`).
    private var entryReadBack: LostAnswer<TournamentDetail> {
        LostAnswer(category: .tournaments,
                   logger: logger,
                   leavesOutcomeUnknown: { $0.leavesTournamentWriteOutcomeUnknown },
                   isWorthAnotherLook: { $0.isTournamentRefusal && $0 != .termsRequired && $0 != .tryAgain },
                   refetch: { [self] in try await repository.tournament(id: destination.id) },
                   apply: { [self] in accept($0) })
    }
}
