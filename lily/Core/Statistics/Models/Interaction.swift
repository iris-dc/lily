import Foundation

/// The taps the backend cannot see for itself. Wire names are snake_case, like the backend's `InteractionKind`.
nonisolated enum InteractionKind: String, Codable, Sendable {
    case eventViewed = "event_viewed"
    case filterApplied = "filter_applied"
    case presentationChanged = "presentation_changed"
}

/// One reported interaction. By construction it carries ids, types and flags only: never a coordinate, an amount, a date
/// range or free text, so nothing here can place or quote the user.
nonisolated struct Interaction: Encodable, Equatable, Sendable {
    let kind: InteractionKind
    let occurredAt: Date
    var eventId: String?
    var eventType: EventType?
    var hostUserId: String?
    var filter: FilterSummary?
    var presentation: String?

    static func viewed(_ event: SportEvent, at date: Date) -> Interaction {
        Interaction(kind: .eventViewed,
                    occurredAt: date,
                    eventId: event.id,
                    eventType: event.type,
                    hostUserId: event.hostUserId)
    }

    static func filterApplied(_ filter: EventFilter, at date: Date) -> Interaction {
        Interaction(kind: .filterApplied, occurredAt: date, filter: FilterSummary(filter))
    }

    static func presentationChanged(_ presentation: EventsPresentation, at date: Date) -> Interaction {
        Interaction(kind: .presentationChanged, occurredAt: date, presentation: presentation.wireValue)
    }
}
