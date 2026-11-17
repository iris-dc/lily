import Foundation
@testable import lily

extension InboxItem {
    /// A pending invite into a fixture game; ids given by tests sort as ULIDs do.
    static func eventInvite(id: String = "01J9INBOX00000000000000008",
                            eventID: String = "e1",
                            title: String = "Sunset 5-a-side",
                            type: EventType = .football,
                            startsAt: Date = Date(timeIntervalSince1970: 1_800_003_600),
                            locationName: String = "Tempelhofer Feld",
                            inviterName: String = "Noor",
                            status: InviteStatus = .pending,
                            createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
                            expiresAt: Date = Date(timeIntervalSince1970: 1_801_209_600),
                            respondedAt: Date? = nil) -> InboxItem {
        InboxItem(id: id,
                  kind: .eventInvite,
                  createdAt: createdAt,
                  eventInvite: EventInvitePayload(eventId: eventID,
                                                  title: title,
                                                  type: type,
                                                  startsAt: startsAt,
                                                  locationName: locationName,
                                                  inviterUserId: "u-\(inviterName.lowercased())",
                                                  inviterName: inviterName,
                                                  status: status,
                                                  expiresAt: expiresAt,
                                                  respondedAt: respondedAt))
    }
}

/// Laurel's strict JSON for the event inbox item, the accept answer and the invite send
/// (`InboxControllerIt.page_answersTheEventInviteKind`, `EventInviteControllerIt`), decoded as it is so a key that
/// moves on either side fails a test.
extension ContractSamples {
    static let eventInviteItemID = "01JE7K0C4X9S1U3W5Y7A9C1E3G"
    static let eventInviteItem = """
    {"id":"\(eventInviteItemID)","kind":"event_invite","createdAt":"2026-11-15T12:00:00Z",\
    "eventInvite":{"eventId":"evt_03","title":"Sunset 5-a-side","type":"football",\
    "startsAt":"2026-11-16T18:00:00Z","locationName":"Riverside Pitch 2","inviterUserId":"seed-noor",\
    "inviterName":"Noor","status":"pending","expiresAt":"2026-11-29T12:00:00Z"}}
    """
    /// The item once accepted, as the accept answer carries it.
    static let acceptedEventInviteItem = eventInviteItem
        .replacingOccurrences(of: #""status":"pending""#, with: #""status":"accepted""#)
        .replacingOccurrences(of: #""expiresAt":"2026-11-29T12:00:00Z"}"#,
                              with: #""expiresAt":"2026-11-29T12:00:00Z","respondedAt":"2026-11-15T12:01:00Z"}"#)
    /// The event as the accept answers it: joined, with the room's `channelEpoch` mirror the wire always sends.
    static let acceptedEvent = """
    {"id":"evt_03","title":"Sunset 5-a-side","type":"football","startsAt":"2026-11-16T18:00:00Z",\
    "location":{"name":"Riverside Pitch 2","coordinate":{"latitude":52.529,"longitude":13.387}},\
    "capacity":10,"allowsExtraParticipants":false,"participantCount":7,"hostUserId":"seed-marta","hostName":"Marta",\
    "isJoined":true,"group":{"id":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","name":"Kreuzberg Kickers",\
    "visibility":"public","isDeleted":false},"channelEpoch":2}
    """
    /// `POST /api/me/inbox/{id}/accept` for an event invite: `{item, event}`, no group or tournament key.
    static let inviteAcceptedEvent = #"{"item":\#(acceptedEventInviteItem),"event":\#(acceptedEvent)}"#
    /// `POST /api/events/{id}/invites` -> 201 `SentEventInvite`.
    static let sentEventInvite = """
    {"id":"\(eventInviteItemID)","eventId":"evt_03","inviteeUserId":"seed-noor","inviteeName":"Noor",\
    "status":"pending","createdAt":"2026-11-15T12:00:00Z","expiresAt":"2026-11-29T12:00:00Z"}
    """
    /// `inbox_item` on `users/<sub>`, carrying an event invite like any kind.
    static let eventInboxItemEnvelope = #"{"type":"inbox_item","item":\#(eventInviteItem)}"#
}
