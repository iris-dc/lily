import Foundation
@testable import lily

extension InboxItem {
    /// A pending invite into a private climbing group; ids given by tests sort as ULIDs do (plain strings compared).
    static func invite(id: String = "01J9INBOX00000000000000002",
                       groupID: String = "g3",
                       groupName: String = "Climbing Buddies",
                       visibility: GroupVisibility = .private,
                       inviterName: String = "Noor",
                       status: InviteStatus = .pending,
                       createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
                       expiresAt: Date = Date(timeIntervalSince1970: 1_800_604_800),
                       respondedAt: Date? = nil) -> InboxItem {
        InboxItem(id: id,
                  kind: .groupInvite,
                  createdAt: createdAt,
                  invite: InvitePayload(groupId: groupID,
                                        groupName: groupName,
                                        groupVisibility: visibility,
                                        inviterUserId: "u-\(inviterName.lowercased())",
                                        inviterName: inviterName,
                                        status: status,
                                        expiresAt: expiresAt,
                                        respondedAt: respondedAt))
    }

    /// A reminder for a game an hour ahead of the fixture clock.
    static func reminder(id: String = "01J9INBOX00000000000000001",
                         eventID: String = "e",
                         title: String = "Sunset 5-a-side",
                         locationName: String = "Tempelhofer Feld",
                         startsAt: Date = Date(timeIntervalSince1970: 1_800_003_600),
                         groupName: String? = "Kreuzberg Kickers",
                         createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> InboxItem {
        InboxItem(id: id,
                  kind: .eventReminder,
                  createdAt: createdAt,
                  reminder: ReminderPayload(eventId: eventID,
                                            title: title,
                                            locationName: locationName,
                                            startsAt: startsAt,
                                            groupName: groupName))
    }

    /// A kind this build does not know, as a newer backend might send it.
    static func unknown(id: String = "01J9INBOX00000000000000003",
                        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> InboxItem {
        InboxItem(id: id, kind: .unknown("poke"), createdAt: createdAt)
    }

    /// The notice a host's account deletion leaves for a joined upcoming game; the event itself is gone.
    static func eventCancelled(id: String = "01J9INBOX00000000000000006",
                               eventID: String = "e-cancelled",
                               title: String = "Sunset 5-a-side",
                               startsAt: Date = Date(timeIntervalSince1970: 1_800_172_800),
                               createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> InboxItem {
        InboxItem(id: id,
                  kind: .eventCancelled,
                  createdAt: createdAt,
                  eventCancelled: EventCancelledPayload(eventId: eventID, title: title, startsAt: startsAt))
    }

    /// The notice the deletion job writes to a group's new owner.
    static func groupOwnershipTransferred(id: String = "01J9INBOX00000000000000007",
                                          groupID: String = "g9",
                                          groupName: String = "Sunday Padel Crew",
                                          createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> InboxItem {
        let payload = GroupOwnershipTransferredPayload(groupId: groupID, groupName: groupName)
        return InboxItem(id: id, kind: .groupOwnershipTransferred, createdAt: createdAt, groupOwnershipTransferred: payload)
    }
}

extension InboxPage {
    static func fixture(_ items: [InboxItem],
                        hasMore: Bool = false,
                        nextBefore: String? = nil,
                        lastReadId: String? = nil) -> InboxPage {
        InboxPage(items: items, hasMore: hasMore, nextBefore: nextBefore, lastReadId: lastReadId)
    }
}

/// The inbox JSON exactly as the contract (inbox plan, section 2) shows it.
extension ContractSamples {
    static let inboxInviteID = "01J9B4X6KQ2M8N0P3R5T7V9W1Y"
    static let inboxReminderID = "01J9B4Y7KR3N9P1Q4S6T8W0X2Z"
    static let inboxInvite = """
    {"id":"\(inboxInviteID)","kind":"group_invite","createdAt":"2026-09-29T10:00:00Z",\
    "invite":{"groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","groupName":"Sunday Padel Crew","groupVisibility":"private",\
    "inviterUserId":"seed-marta","inviterName":"Marta","status":"pending","expiresAt":"2026-10-06T10:00:00Z"}}
    """
    static let inboxAcceptedInvite = """
    {"id":"\(inboxInviteID)","kind":"group_invite","createdAt":"2026-09-29T10:00:00Z",\
    "invite":{"groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","groupName":"Sunday Padel Crew","groupVisibility":"private",\
    "inviterUserId":"seed-marta","inviterName":"Marta","status":"accepted","expiresAt":"2026-10-06T10:00:00Z",\
    "respondedAt":"2026-09-29T11:00:00Z"}}
    """
    static let inboxReminder = """
    {"id":"\(inboxReminderID)","kind":"event_reminder","createdAt":"2026-09-29T17:30:00Z",\
    "reminder":{"eventId":"evt_01J","title":"Sunset 5-a-side","locationName":"Tempelhofer Feld",\
    "startsAt":"2026-09-29T18:30:00Z","groupName":"Kreuzberg Kickers"}}
    """
    /// A kind this build does not know, with a payload of its own.
    static let inboxUnknownItem = """
    {"id":"01J9B4Z8MS4P0Q2R5T7V9X1Y3A","kind":"poke","createdAt":"2026-09-29T17:31:00Z","poke":{"from":"seed-jonas"}}
    """
    static let inboxPage = """
    {"items":[\(inboxInvite),\(inboxReminder)],"hasMore":true,"nextBefore":"\(inboxInviteID)","lastReadId":"\(inboxInviteID)"}
    """
    /// A first page for a user who never read anything, without the optional fields.
    static let minimalInboxPage = #"{"items":[],"hasMore":false}"#
    static let inviteAccepted = #"{"item":\#(inboxAcceptedInvite),"group":\#(group)}"#
    private static let acceptedStatus = #""status":"accepted""#
    private static let declinedStatus = #""status":"declined""#
    static let inboxDeclinedInvite = inboxAcceptedInvite.replacingOccurrences(of: acceptedStatus, with: declinedStatus)
    static let inviteDeclined = #"{"item":\#(inboxDeclinedInvite)}"#
    static let inboxReadMarker = #"{"lastReadId":"\#(inboxInviteID)"}"#
    static let inboxItemEnvelope = #"{"type":"inbox_item","item":\#(inboxInvite)}"#
    static let inboxEventCancelledID = "01JE5K0C4V7Q9S1T3V5X7Z9B1D"
    static let inboxOwnershipID = "01JE5K0C4W8R0T2V4X6Z8B0D2F"
    /// The account-deletion contract (section 8): the notice every participant of a removed upcoming event receives.
    static let inboxEventCancelled = """
    {"id":"\(inboxEventCancelledID)","kind":"event_cancelled","createdAt":"2026-11-07T10:00:00Z",\
    "eventCancelled":{"eventId":"evt_01J","title":"Sunset 5-a-side","startsAt":"2026-11-09T18:30:00Z"}}
    """
    /// The account-deletion contract (section 8): the notice a group's new owner receives once the handoff commits.
    static let inboxOwnershipTransferred = """
    {"id":"\(inboxOwnershipID)","kind":"group_ownership_transferred","createdAt":"2026-11-07T10:00:01Z",\
    "groupOwnershipTransferred":{"groupId":"7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d","groupName":"Sunday Padel Crew"}}
    """
}
