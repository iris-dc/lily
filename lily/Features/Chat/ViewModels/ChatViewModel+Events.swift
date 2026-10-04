import Foundation

/// What a system row shows and opens: the game behind an `event_created` row and the tournament behind a tournament
/// note (the wire carries ids, and for a result or a winner the server-rendered text; the title of a game and the format
/// of a tournament are fetched once per screen), copying, and whether the caller may delete a message.
extension ChatViewModel {
    func systemText(for message: ChatMessage) -> String {
        switch message.kind {
        case .eventCreated:
            let title = message.eventId.flatMap { linked.events[$0]?.title } ?? AppBranding.Chat.eventCreatedFallbackTitle
            return AppBranding.Chat.eventCreated(by: message.senderName, title: title)
        case .tournamentStarted:
            return AppBranding.Chat.tournamentStarted(format: linkedTournament(for: message)?.format)
        case .matchResult:
            return message.text ?? AppBranding.Chat.matchResultFallback
        case .matchDisputed:
            return AppBranding.Chat.matchDisputed(message.text)
        case .tournamentCompleted:
            return AppBranding.Chat.tournamentCompleted(winner: message.text)
        case .text, .unknown:
            return message.text ?? ""
        }
    }

    /// Fetches what a system row needs to word itself (a game's title, a started tournament's format); quiet when it
    /// cannot, the row keeps its fallback.
    func loadLinkedContent(for message: ChatMessage) async {
        if let eventID = message.eventId, linked.events[eventID] == nil {
            if case .failure(let error) = await fetchEvent(id: eventID), !AppError.isCancellation(error) {
                logger.warning(.chat, "Event \(eventID) behind a system row in group \(group.id) is unavailable: \(error)")
            }
        }
        if message.kind == .tournamentStarted, let tournamentID = message.tournamentId, linked.tournaments[tournamentID] == nil {
            await fetchTournament(id: tournamentID)
        }
    }

    /// Where the row leads: the game (gone or unreachable, it reaches the popup) or the tournament with the match the
    /// row names selected. The room is the tournament, so its name is on hand without a fetch.
    func destination(for message: ChatMessage) async -> SystemRowDestination? {
        if message.kind.isTournamentNote, let tournamentID = message.tournamentId {
            let name = linked.tournaments[tournamentID]?.name ?? group.name
            return .tournament(TournamentDestination(id: tournamentID, name: name, matchID: message.matchId))
        }
        guard let eventID = message.eventId else { return nil }
        switch await fetchEvent(id: eventID) {
        case .success(let event):
            return .event(event)
        case .failure(let error):
            report(error, during: "Opening the game behind a system row")
            return nil
        }
    }

    func copy(_ message: ChatMessage) {
        guard let text = message.text else { return }
        pasteboard.copy(text)
    }

    /// The sender and the group's admins may delete; a tombstone has nothing left to delete.
    func canDelete(_ message: ChatMessage) -> Bool {
        guard !message.isDeleted, !message.isSystem else { return false }
        return message.isSent(by: identity.currentUserID) || GroupAccess(group: group, userID: identity.currentUserID).canEdit
    }

    private func linkedTournament(for message: ChatMessage) -> Tournament? {
        message.tournamentId.flatMap { linked.tournaments[$0] }
    }

    private func fetchEvent(id: String) async -> Result<SportEvent, any Error> {
        if let known = linked.events[id] { return .success(known) }
        do {
            let event = try await links.events.event(id: id)
            linked.events[id] = event
            return .success(event)
        } catch {
            return .failure(error)
        }
    }

    private func fetchTournament(id: String) async {
        do {
            linked.tournaments[id] = try await links.tournaments.tournament(id: id).tournament
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.chat, "Tournament \(id) behind a system row in group \(group.id) is unavailable: \(error)")
        }
    }
}
