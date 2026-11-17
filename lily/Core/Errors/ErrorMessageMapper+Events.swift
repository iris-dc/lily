import Foundation

/// Copy for what a host does to their own game (creating and editing it), for inviting people into one and for the
/// event's room when none can be fetched; `eventMessage(for:)` falls through to here, so every switch stays
/// under the complexity limit.
nonisolated extension ErrorMessageMapper {
    static func hostMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .eventCreationFailed:
            ErrorMessage(title: localized("Couldn't create your event"),
                         body: localized("Check the details and try again in a moment."))
        case .eventUpdateFailed:
            ErrorMessage(title: localized("Couldn't save your changes"),
                         body: localized("Check the details and try again in a moment."))
        case .placeNotFound:
            ErrorMessage(title: localized("Couldn't find this place"),
                         body: localized("Check the place name, or set the spot on the map."))
        case .notHost:
            ErrorMessage(title: localized("Not your event"), body: localized("Only the host can change an event."))
        case .capacityTooLow:
            ErrorMessage(title: localized("Too few spots"),
                         body: localized("Keep at least as many spots as players who already joined."))
        case .eventChatUnavailable:
            ErrorMessage(title: localized("Chat unavailable"),
                         body: localized("The chat isn't available for this event."))
        default:
            eventInviteMessage(for: error)
        }
    }

    /// Inviting people into an event: the join codes read differently on an invite, plus the start-time refusal the
    /// backend answers with `EVENT_STARTED` (joining stays open; only the invites close).
    private static func eventInviteMessage(for error: AppError) -> ErrorMessage {
        switch error {
        case .eventStarted:
            ErrorMessage(title: localized("This event has already started"),
                         body: localized("Invites can only be sent before the start."))
        case .inviteeAlreadyJoined:
            ErrorMessage(title: localized("They're already in this event"), body: localized("No invite needed."))
        case .cannotInviteToEvent:
            ErrorMessage(title: localized("Only players can invite"),
                         body: localized("Join the event first, or ask the host to send the invite."))
        case .eventInviteLimit:
            ErrorMessage(title: localized("Can't invite more people"),
                         body: localized("This event has invited as many people as it can."))
        default:
            unknownMessage
        }
    }
}
