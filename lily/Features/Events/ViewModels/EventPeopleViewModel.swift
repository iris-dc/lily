import Foundation
import Observation

/// Owns the pushed "Who's in" list: the participants of one event, fetched on appear. Its own view model, not the
/// detail's, so the screen is pushed by value from any stack (two details of one kind may share a stack) and always
/// shows the list of the event that was tapped.
@Observable
final class EventPeopleViewModel {
    let event: SportEvent
    private(set) var participants: [EventParticipant] = []
    private(set) var isLoading = false
    /// At least one fetch answered: the empty Going line is then a fact, never a failure's silence.
    private(set) var hasLoaded = false

    private let repository: any EventRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(event: SportEvent,
         repository: any EventRepository,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging) {
        self.event = event
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
    }

    /// The host as the backend lists them; before the list answers (or after a failed fetch), the event's own host
    /// stands in, so the screen never hides who hosts. An event without a host id (old fixtures) waits for the list.
    var hosting: [EventParticipant] {
        let listed = participants.filter(\.isHost)
        if !listed.isEmpty { return listed }
        guard let hostId = event.hostUserId else { return [] }
        return [EventParticipant(userId: hostId,
                                 displayName: Tombstone.displayName(event.hostName, deleted: event.deleted),
                                 joinedAt: event.startsAt,
                                 isHost: true)]
    }

    var going: [EventParticipant] { participants.filter { !$0.isHost } }

    func isSelf(_ participant: EventParticipant) -> Bool {
        participant.userId == identity.currentUserID
    }

    /// On appear; a failure reaches the popup and keeps the last list.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            participants = try await repository.participants(eventId: event.id)
            hasLoaded = true
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.events, "Loading participants of event \(event.id) failed: \(error)")
            errorCenter.report(error)
        }
    }
}
