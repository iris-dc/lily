import Foundation

/// The two items of a mock inbox: a game reminder for the first fixture event, then a pending invite from Noor into
/// Climbing Buddies, the private group nothing else reaches. Ids sort like ULIDs, the invite being the newest.
nonisolated enum MockInboxFixtures {
    static let reminderID = itemID(index: 1)
    static let inviteID = itemID(index: 2)
    static let inviterName = "Noor"
    private static let idPrefix = "01J8MOCKNB"
    private static let idDigits = 16
    /// How long before the launch each item was written; the invite is the more recent one.
    private static let reminderAge: TimeInterval = 10 * 60
    private static let inviteAge: TimeInterval = 60

    /// Sortable like a ULID: a fixed prefix and a zero-padded sequence.
    static func itemID(index: Int) -> String {
        idPrefix + String(format: "%0\(idDigits)d", index)
    }

    static func make(now: Date) -> [InboxItem] {
        [reminder(now: now), invite(now: now)].compactMap { $0 }
    }

    /// The reminder names the first mock event as it stands (title, place, group), starting an hour ahead.
    private static func reminder(now: Date) -> InboxItem? {
        guard let event = MockEventFixtures.make(now: now, count: 1).first else { return nil }
        let reminder = ReminderPayload(eventId: event.id,
                                       title: event.title,
                                       locationName: event.locationName,
                                       startsAt: now.addingTimeInterval(AppConfig.Inbox.mockReminderLead),
                                       groupName: event.group?.name)
        return InboxItem(id: reminderID,
                         kind: .eventReminder,
                         createdAt: now.addingTimeInterval(-reminderAge),
                         reminder: reminder)
    }

    private static func invite(now: Date) -> InboxItem? {
        guard let group = MockGroupFixtures.ref(for: MockGroupFixtures.climbingID) else { return nil }
        let expiresAt = now.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry)
        let invite = InvitePayload(groupId: group.id,
                                   groupName: group.name,
                                   groupVisibility: group.visibility,
                                   inviterUserId: MockGroupFixtures.memberID(for: inviterName),
                                   inviterName: inviterName,
                                   expiresAt: expiresAt)
        return InboxItem(id: inviteID,
                         kind: .groupInvite,
                         createdAt: now.addingTimeInterval(-inviteAge),
                         invite: invite)
    }
}
