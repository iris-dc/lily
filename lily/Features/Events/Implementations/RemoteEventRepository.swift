import Foundation

/// Events from the Laurel backend. Failures arrive as `AppError`, ready for the popup.
final class RemoteEventRepository: EventRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func events(in scope: EventScope, near position: Coordinate?) async throws -> [SportEvent] {
        var query = [URLQueryItem(name: AppConfig.API.Query.scope, value: scope.queryValue)]
        if scope == .upcoming, let position {
            query += position.queryItems
        }
        return try await client.send(.get(AppConfig.API.Paths.events, query: query), failingWith: .eventsUnavailable)
    }

    func event(id: String) async throws -> SportEvent {
        try await client.send(.get(AppConfig.API.Paths.event(id: id)), failingWith: .eventsUnavailable)
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
}

private extension EventScope {
    /// Value of the `scope` query parameter.
    var queryValue: String {
        switch self {
        case .upcoming: "upcoming"
        case .joined: "joined"
        }
    }
}

private extension Coordinate {
    /// `lat` and `lon` at `AppConfig.Events.positionPrecision`, rounded first and then printed with exactly that many
    /// decimals and a `.` whatever the locale: `"\(double)"` could print `52.540000000000006` or an exponent.
    var queryItems: [URLQueryItem] {
        let decimals = AppConfig.Events.positionPrecision
        let coarse = rounded(toDecimals: decimals)
        let format = "%.\(decimals)f"
        return [URLQueryItem(name: AppConfig.API.Query.latitude, value: String(format: format, coarse.latitude)),
                URLQueryItem(name: AppConfig.API.Query.longitude, value: String(format: format, coarse.longitude))]
    }
}
