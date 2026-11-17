import Foundation

/// The `eventInvite` payload of an `event_invite` item: who asked the caller into which event, what and when it is,
/// and where the answer stands. An accept joins the game as a tap on Join would.
nonisolated struct EventInvitePayload: Hashable, Codable, Sendable, InviteAnswer {
    let eventId: String
    let title: String
    let type: EventType
    let startsAt: Date
    let locationName: String
    let inviterUserId: String
    let inviterName: String
    let status: InviteStatus
    let expiresAt: Date
    /// Present once the caller accepted or declined.
    let respondedAt: Date?

    init(eventId: String,
         title: String,
         type: EventType,
         startsAt: Date,
         locationName: String,
         inviterUserId: String,
         inviterName: String,
         status: InviteStatus = .pending,
         expiresAt: Date,
         respondedAt: Date? = nil) {
        self.eventId = eventId
        self.title = title
        self.type = type
        self.startsAt = startsAt
        self.locationName = locationName
        self.inviterUserId = inviterUserId
        self.inviterName = inviterName
        self.status = status
        self.expiresAt = expiresAt
        self.respondedAt = respondedAt
    }

    func responding(_ status: InviteStatus, at date: Date) -> EventInvitePayload {
        EventInvitePayload(eventId: eventId,
                           title: title,
                           type: type,
                           startsAt: startsAt,
                           locationName: locationName,
                           inviterUserId: inviterUserId,
                           inviterName: inviterName,
                           status: status,
                           expiresAt: expiresAt,
                           respondedAt: date)
    }
}
