import Foundation

/// The taps the backend cannot see for itself. Wire names are snake_case, like the backend's `InteractionKind`.
nonisolated enum InteractionKind: String, Codable, Sendable {
    case eventViewed = "event_viewed"
    case filterApplied = "filter_applied"
    case presentationChanged = "presentation_changed"
    case groupViewed = "group_viewed"
    case groupSearchPerformed = "group_search_performed"
    case chatOpened = "chat_opened"
    case tournamentViewed = "tournament_viewed"
}

/// One reported interaction. By construction it carries ids, types and flags only: never a coordinate, an amount, a date
/// range, a query or free text, so nothing here can place or quote the user.
nonisolated struct Interaction: Encodable, Equatable, Sendable {
    let kind: InteractionKind
    let occurredAt: Date
    var eventId: String?
    var eventType: EventType?
    var hostUserId: String?
    var filter: FilterSummary?
    var presentation: String?
    var groupId: String?
    var groupVisibility: GroupVisibility?
    var hasQuery: Bool?
    var resultCount: Int?
    var tournamentId: String?
    var tournamentFormat: TournamentFormat?

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

    /// The group's id, visibility and event type (its type feeds the caller's preferences; "any type" says nothing).
    static func groupViewed(_ group: SportGroup, at date: Date) -> Interaction {
        Interaction(kind: .groupViewed,
                    occurredAt: date,
                    eventType: group.type,
                    groupId: group.id,
                    groupVisibility: group.visibility)
    }

    /// Whether a name was typed and how many groups came back; never the name.
    static func groupSearchPerformed(hasQuery: Bool, resultCount: Int, at date: Date) -> Interaction {
        Interaction(kind: .groupSearchPerformed, occurredAt: date, hasQuery: hasQuery, resultCount: resultCount)
    }

    static func chatOpened(groupID: String, at date: Date) -> Interaction {
        Interaction(kind: .chatOpened, occurredAt: date, groupId: groupID)
    }

    /// The tournament's id, format and event type; never its name.
    static func tournamentViewed(_ tournament: Tournament, at date: Date) -> Interaction {
        Interaction(kind: .tournamentViewed,
                    occurredAt: date,
                    eventType: tournament.type,
                    tournamentId: tournament.id,
                    tournamentFormat: tournament.format)
    }
}
