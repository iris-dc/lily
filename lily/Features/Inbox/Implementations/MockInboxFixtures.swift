import Foundation

/// The four items of a mock inbox, oldest first: Noor's invite into the Padel Open (the private tournament nothing else
/// reaches), a game reminder for the first fixture event, a match reminder for the caller's scheduled table-tennis match,
/// then Noor's invite into Climbing Buddies, the private group nothing else reaches. Ids sort like ULIDs, the group
/// invite being the newest.
nonisolated enum MockInboxFixtures {
    static let tournamentInviteID = itemID(index: 1)
    static let reminderID = itemID(index: 2)
    static let matchReminderID = itemID(index: 3)
    static let inviteID = itemID(index: 4)
    static let inviterName = "Noor"
    private static let idPrefix = "01J8MOCKNB"
    private static let idDigits = 16
    /// How long before the launch each item was written; the group invite is the most recent one.
    private static let tournamentInviteAge: TimeInterval = 2 * 24 * 60 * 60
    private static let reminderAge: TimeInterval = 10 * 60
    private static let matchReminderAge: TimeInterval = 5 * 60
    private static let inviteAge: TimeInterval = 60

    /// Sortable like a ULID: a fixed prefix and a zero-padded sequence.
    static func itemID(index: Int) -> String {
        idPrefix + String(format: "%0\(idDigits)d", index)
    }

    static func make(now: Date) -> [InboxItem] {
        [tournamentInvite(now: now), reminder(now: now), matchReminder(now: now), invite(now: now)].compactMap { $0 }
    }

    /// Noor asks the caller into her Padel Open as it stands: individual, so an accept enters them.
    private static func tournamentInvite(now: Date) -> InboxItem {
        let tournament = MockTournamentFixtures.padelOpen(now: now).tournament
        let invite = TournamentInvitePayload(tournamentId: tournament.id,
                                             tournamentName: tournament.name,
                                             type: tournament.type,
                                             format: tournament.format,
                                             teamSize: tournament.teamSize,
                                             inviterUserId: tournament.organizerUserId,
                                             inviterName: tournament.organizerName,
                                             expiresAt: now.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry))
        return InboxItem(id: tournamentInviteID,
                         kind: .tournamentInvite,
                         createdAt: now.addingTimeInterval(-tournamentInviteAge),
                         tournamentInvite: invite)
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

    /// The caller's scheduled table-tennis match as the fixture holds it: the opponent, the time and the hall.
    private static func matchReminder(now: Date) -> InboxItem? {
        let fixtures = MockTournamentFixtures.self
        guard let detail = fixtures.make(now: now).first(where: { $0.id == fixtures.tableTennisID }),
              let match = detail.match(id: fixtures.tableTennisScheduledMatchID),
              let scheduledAt = match.scheduledAt else { return nil }
        let opponent = detail.opponent(in: match, of: fixtures.callerMarker)
        let reminder = MatchReminderPayload(tournamentId: detail.id,
                                            tournamentName: detail.tournament.name,
                                            matchId: match.id,
                                            opponentName: opponent?.name ?? AppBranding.Tournaments.toBeDecided,
                                            scheduledAt: scheduledAt,
                                            locationName: match.location?.name)
        return InboxItem(id: matchReminderID,
                         kind: .matchReminder,
                         createdAt: now.addingTimeInterval(-matchReminderAge),
                         matchReminder: reminder)
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
