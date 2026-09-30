import Foundation

/// Events from the Laurel backend. Failures arrive as `AppError`, ready for the popup.
final class RemoteEventRepository: EventRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func events(in scope: EventScope, near position: Coordinate?) async throws -> [SportEvent] {
        try await client.send(Self.listRequest(for: scope, near: position), failingWith: .eventsUnavailable)
    }

    func event(id: String) async throws -> SportEvent {
        try await client.send(.get(AppConfig.API.Paths.event(id: id)), failingWith: .eventsUnavailable)
    }

    /// The list comes as `{items: [EventParticipant]}` without a cursor.
    func participants(eventId: String) async throws -> [EventParticipant] {
        let request = APIRequest<Page<EventParticipant>>.get(AppConfig.API.Paths.participants(eventId: eventId))
        let page = try await client.send(request, failingWith: .eventsUnavailable)
        return page.items
    }

    func join(eventId: String) async throws -> SportEvent {
        try await client.send(.post(AppConfig.API.Paths.participants(eventId: eventId)), failingWith: .participationFailed)
    }

    func leave(eventId: String) async throws -> SportEvent {
        try await client.send(.delete(AppConfig.API.Paths.participants(eventId: eventId)), failingWith: .participationFailed)
    }

    func create(_ draft: EventDraft) async throws -> SportEvent {
        guard let payload = CreateEventPayload(draft: draft) else { throw AppError.eventCreationFailed }
        return try await client.send(.post(AppConfig.API.Paths.events, body: payload), failingWith: .eventCreationFailed)
    }

    func update(id: String, _ draft: EventDraft) async throws -> SportEvent {
        guard let payload = UpdateEventPayload(draft: draft) else { throw AppError.eventUpdateFailed }
        return try await client.send(.put(AppConfig.API.Paths.event(id: id), body: payload), failingWith: .eventUpdateFailed)
    }
}

private extension RemoteEventRepository {
    /// A group's games have a resource of their own; the other scopes are a query on `/api/events`, with the position
    /// only on Explore, which the backend orders by relevance for the caller.
    static func listRequest(for scope: EventScope, near position: Coordinate?) -> APIRequest<[SportEvent]> {
        switch scope {
        case .group(let id):
            .get(AppConfig.API.Paths.groupEvents(id: id))
        case .upcoming:
            .get(AppConfig.API.Paths.events, query: [scopeItem("upcoming")] + (position?.queryItems ?? []))
        case .joined:
            .get(AppConfig.API.Paths.events, query: [scopeItem("joined")])
        }
    }

    private static func scopeItem(_ value: String) -> URLQueryItem {
        URLQueryItem(name: AppConfig.API.Query.scope, value: value)
    }
}

private extension Coordinate {
    /// `lat` and `lon` of the `coarse` position, printed with exactly `AppConfig.Events.positionPrecision` decimals and
    /// a `.` whatever the locale: `"\(double)"` could print `52.540000000000006` or an exponent.
    var queryItems: [URLQueryItem] {
        let position = coarse
        let format = "%.\(AppConfig.Events.positionPrecision)f"
        return [URLQueryItem(name: AppConfig.API.Query.latitude, value: String(format: format, position.latitude)),
                URLQueryItem(name: AppConfig.API.Query.longitude, value: String(format: format, position.longitude))]
    }
}
