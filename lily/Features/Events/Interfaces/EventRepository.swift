import Foundation

/// Events boundary. Join and leave return the event as the server now sees it, so screens show the real count.
protocol EventRepository {
    /// `position` lets the backend order `.upcoming` by relevance for the caller; it is sent rounded to about a
    /// kilometre and only for that scope. `nil` (unknown or `.joined`) keeps the backend's default order.
    func events(in scope: EventScope, near position: Coordinate?) async throws -> [SportEvent]
    /// One event as the server sees it now; throws `AppError.eventNotFound` when it is gone.
    func event(id: String) async throws -> SportEvent
    func join(eventId: String) async throws -> SportEvent
    func leave(eventId: String) async throws -> SportEvent
    /// Creates the event for the caller, who hosts it and is its first participant; answers the event as stored.
    /// Repeating a create with the same `EventDraft.clientId` answers the same event instead of a second one.
    func create(_ draft: EventDraft) async throws -> SportEvent
}
