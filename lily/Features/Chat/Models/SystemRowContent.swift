import Foundation
import Observation

/// What the system rows of one room show and open: the game behind an `event_created` row and the tournament behind a
/// tournament note (the wire carries ids, and for a result or a winner the server-rendered text; the title of a game and
/// the format of a tournament are fetched once per screen). Observable because a row (`SystemMessageRow`) re-renders
/// when the game or tournament behind it arrives; held by `ChatViewModel` as one object.
@Observable
final class SystemRowContent {
    /// The repositories behind the rows and the change counters a live row bumps.
    let links: SystemRowLinks
    /// The games and tournaments fetched once each, or known to be gone.
    private(set) var linked = LinkedContent()
    private let groupID: String
    private let logger: any Logging

    init(links: SystemRowLinks, groupID: String, logger: any Logging) {
        self.links = links
        self.groupID = groupID
        self.logger = logger
    }

    func text(for message: ChatMessage) -> String {
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
    /// cannot, the row keeps its fallback. One the backend says is gone is never asked for again; a transient failure
    /// is asked again the next time the row appears.
    func load(for message: ChatMessage) async {
        if let eventID = message.eventId, linked.needsEvent(eventID) {
            if case .failure(let error) = await fetchEvent(id: eventID), !AppError.isCancellation(error) {
                if error as? AppError == .eventNotFound { linked.unavailableEventIDs.insert(eventID) }
                logger.warning(.chat, "Event \(eventID) behind a system row in group \(groupID) is unavailable: \(error)")
            }
        }
        if message.kind == .tournamentStarted, let tournamentID = message.tournamentId, linked.needsTournament(tournamentID) {
            await fetchTournament(id: tournamentID)
        }
    }

    /// Where a row leads: `.success(nil)` for a row that opens nothing (a text row); a tournament note needs no fetch
    /// (the room is the tournament, `roomName` names it until the detail loaded) and carries the match the row names;
    /// a game is fetched, and a failure is answered, never reported, so the room decides what the caller sees.
    func destination(for message: ChatMessage, roomName: String) async -> Result<SystemRowDestination?, any Error> {
        if message.kind.isTournamentNote, let tournamentID = message.tournamentId {
            let name = linked.tournaments[tournamentID]?.name ?? roomName
            return .success(.tournament(TournamentDestination(id: tournamentID, name: name, matchID: message.matchId)))
        }
        guard let eventID = message.eventId else { return .success(nil) }
        switch await fetchEvent(id: eventID) {
        case .success(let event): return .success(.event(event))
        case .failure(let error): return .failure(error)
        }
    }

    /// A live row arrived: the lists behind the chat reload for its kind (see `SystemRowLinks.recordChange(for:)`).
    func recordChange(for kind: MessageKind) {
        links.recordChange(for: kind)
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
            if error as? AppError == .tournamentNotFound { linked.unavailableTournamentIDs.insert(id) }
            logger.warning(.chat, "Tournament \(id) behind a system row in group \(groupID) is unavailable: \(error)")
        }
    }
}

/// The games and tournaments behind the system rows on screen, fetched once each, or known to be gone.
struct LinkedContent {
    var events: [String: SportEvent] = [:]
    var tournaments: [String: Tournament] = [:]
    /// Ids the backend answered not found for: a system row's load asks for them no more (a deleted game earned a GET
    /// and a warning on every scroll-in of its row), while a transient failure leaves the row to ask again.
    var unavailableEventIDs: Set<String> = []
    var unavailableTournamentIDs: Set<String> = []

    /// Whether a row's load should ask for the game: not known yet and not known to be gone.
    func needsEvent(_ id: String) -> Bool {
        events[id] == nil && !unavailableEventIDs.contains(id)
    }

    func needsTournament(_ id: String) -> Bool {
        tournaments[id] == nil && !unavailableTournamentIDs.contains(id)
    }
}
