import Foundation

/// Fixture events with in-memory joins, for previews, UI tests and `-mock-events` runs without a backend. The rooms
/// live in the group mock (`rooms`), which every create and participation write mirrors into, as the backend's
/// transactions do.
final class MockEventRepository: EventRepository {
    private var events: [SportEvent]
    /// The group mock the rooms live in; wired right after construction (`GroupRepositories.mock`), absent in tests
    /// that need no rooms. Wiring registers a room for any held event the group fixtures do not ship (the appended
    /// deleted-host game): every event has a room, as on the backend.
    var rooms: MockGroupRepository? {
        didSet {
            guard let rooms else { return }
            for event in events where rooms.find(event.id) == nil {
                rooms.registerEventRoom(for: event, role: event.participates ? .member : nil)
            }
        }
    }
    /// Who creates events; the backend takes the host from the token, the mock from here.
    private let identity: any IdentityProvider
    /// What divides upcoming from history, fixed at launch like the fixtures' starts.
    private let now: Date
    private let logger: any Logging
    /// `-mock-events-fail`: the next list load throws, the reads by id, joins and creates never do.
    private var failsNextLoad: Bool
    /// The draft behind each game made here, by client id: Laurel compares a repeated create with what it stored and
    /// refuses other details under the same id.
    private var drafts: [String: EventDraft] = [:]

    init(now: Date = .now,
         identity: any IdentityProvider,
         logger: any Logging,
         failsFirstLoad: Bool = false,
         deletedHost: Bool = false) {
        var events = MockEventFixtures.feed(now: now).enumerated().map { index, event in
            event.updatingParticipation(count: event.participantCount,
                                        isJoined: MockEventFixtures.isInitiallyJoined(index: index))
        }
        if deletedHost { events.append(MockEventFixtures.deletedHostEvent(now: now)) }
        self.events = events
        self.now = now
        self.identity = identity
        self.logger = logger
        self.failsNextLoad = failsFirstLoad
    }

    /// The position is ignored: the fixtures keep their start order. Like the backend, Explore never lists a private
    /// group's game; its group's scope and Home do. `.past` adds the dedicated history fixtures, which live outside
    /// the feed: a finished game gets no room and no detail, only its history row.
    func events(in scope: EventScope, near position: Coordinate?) async throws -> [SportEvent] {
        if failsNextLoad {
            failsNextLoad = false
            logger.warning(.events, "Mock events failing the first load on request")
            throw AppError.network
        }
        logger.debug(.events, "Mock events served for scope \(scope)")
        switch scope {
        case .upcoming: return events.filter(\.isListed)
        case .joined: return events.filter(\.participates)
        case .past:
            return (events + MockEventFixtures.pastGames(now: now))
                .filter { $0.participates && $0.startsAt < now }
                .sorted { $0.startsAt > $1.startsAt }
        case .group(let id): return events.filter { $0.group?.id == id }
        }
    }

    func event(id: String) async throws -> SportEvent {
        logger.debug(.events, "Mock event \(id) served")
        return try find(id)
    }

    /// The host (the fixture's name, or the caller for a game created here), then `participantCount - 1` deterministic
    /// roster names, then the caller as "You" when they joined; ids resolve against the group mock's rosters.
    func participants(eventId: String) async throws -> [EventParticipant] {
        let event = try find(eventId)
        let hostID = event.hostUserId ?? MockGroupFixtures.memberID(for: event.hostName)
        let hostJoinedAt = event.startsAt.addingTimeInterval(-MockEventFixtures.hostJoinLead)
        let host = EventParticipant(userId: hostID, displayName: event.hostName, joinedAt: hostJoinedAt, isHost: true)
        let caller = identity.currentUserID.flatMap { $0 == hostID || !event.participates ? nil : $0 }
        let othersCount = max(event.participantCount - 1 - (caller == nil ? 0 : 1), 0)
        let others = MockEventFixtures.participantNames(for: event, count: othersCount).enumerated().map { index, name in
            EventParticipant(userId: MockGroupFixtures.memberID(for: name),
                             displayName: name,
                             joinedAt: hostJoinedAt.addingTimeInterval(Double(index + 1) * MockEventFixtures.joinSpacing),
                             isHost: false)
        }
        let you = caller.map {
            [EventParticipant(userId: $0,
                              displayName: AppBranding.Events.Create.mockHostName,
                              joinedAt: hostJoinedAt.addingTimeInterval(Double(others.count + 1) * MockEventFixtures.joinSpacing),
                              isHost: false)]
        }
        logger.debug(.events, "Mock participants served for event \(eventId)")
        return [host] + others + (you ?? [])
    }

    func join(eventId: String) async throws -> SportEvent {
        let event = try find(eventId)
        guard !event.participates else { throw AppError.alreadyJoined }
        guard !event.isFull else { throw AppError.eventFull }
        let joined = store(event.updatingParticipation(count: event.participantCount + 1, isJoined: true))
        rooms?.admitToEventRoom(for: joined)
        return joined
    }

    /// Like the backend: the host is refused before participation is judged (`HOST_CANNOT_LEAVE` first).
    func leave(eventId: String) async throws -> SportEvent {
        let event = try find(eventId)
        guard !event.isHosted(by: identity.currentUserID) else { throw AppError.hostCannotLeave }
        guard event.participates else { throw AppError.notAParticipant }
        // A leave bumps the epoch mirror, as the backend's room transaction does; the room follows it.
        let left = store(event.updatingParticipation(count: event.participantCount - 1,
                                                     isJoined: false,
                                                     channelEpoch: event.channelEpoch + 1))
        rooms?.leaveEventRoom(for: left)
        return left
    }

    /// Like the backend: the draft's client id is the event id, so a repeated create answers the same event, and the
    /// same id with other details is `EVENT_ID_REUSED`.
    func create(_ draft: EventDraft) async throws -> SportEvent {
        if let existing = events.first(where: { $0.id == draft.clientId }) {
            guard drafts[draft.clientId] == draft else { throw AppError.createIdReused }
            logger.info(.events, "Mock create replayed for event \(existing.id)")
            return existing
        }
        guard let coordinate = draft.coordinate else { throw AppError.eventCreationFailed }
        let event = draft.makeEvent(hostUserId: identity.currentUserID,
                                    hostName: AppBranding.Events.Create.mockHostName,
                                    coordinate: coordinate)
        events.append(event)
        drafts[draft.clientId] = draft
        rooms?.registerEventRoom(for: event)
        logger.info(.events, "Mock event \(event.id) created (\(event.spotsDescription))")
        return event
    }

    /// Like the backend: the host alone, and never a cap below the people already in.
    func update(id: String, _ draft: EventDraft) async throws -> SportEvent {
        let event = try find(id)
        guard event.isHosted(by: identity.currentUserID) else { throw AppError.notHost }
        guard draft.playerLimit != .maximum || draft.capacity >= event.participantCount else { throw AppError.capacityTooLow }
        let updated = store(event.updating(with: draft))
        drafts[id] = draft
        rooms?.syncEventRoom(for: updated)
        logger.info(.events, "Mock event \(updated.id) updated (\(updated.spotsDescription))")
        return updated
    }

    /// The stored event behind an id, for the sibling mocks (the invite mock's gate); `EVENT_NOT_FOUND` otherwise.
    func stored(_ eventId: String) throws -> SportEvent {
        try find(eventId)
    }

    private func find(_ eventId: String) throws -> SportEvent {
        guard let event = events.first(where: { $0.id == eventId }) else { throw AppError.eventNotFound }
        return event
    }

    private func store(_ event: SportEvent) -> SportEvent {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        }
        return event
    }
}
