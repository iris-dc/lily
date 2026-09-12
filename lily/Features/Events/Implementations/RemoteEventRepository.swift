import Foundation

/// Events from the Laurel backend. Failures arrive as `AppError`, ready for the popup.
final class RemoteEventRepository: EventRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func events(in scope: EventScope) async throws -> [SportEvent] {
        let query = [URLQueryItem(name: AppConfig.API.Query.scope, value: scope.queryValue)]
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
