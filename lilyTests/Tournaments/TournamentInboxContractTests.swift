import Foundation
import Testing
@testable import lily

/// Laurel B3's strict JSON (`LaurelTournamentInboxJSON`) decoded with the app's conventions: the two inbox kinds, the
/// two accept answers (no `group` key in either), the invite routes and the room events; plus what the screens read
/// off them.
struct TournamentInboxContractTests {
    private typealias Laurel = LaurelTournamentInboxJSON
    /// 2026-09-21, before the B3 invite expires (2026-10-09), so it is still open.
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func theTournamentInviteDecodesEveryField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: Laurel.tournamentInvite)

        #expect(item.id == Laurel.inviteItemID && item.kind == .tournamentInvite && item.isVisible)
        #expect(item.invite == nil && item.reminder == nil && item.matchReminder == nil)
        let invite = try #require(item.tournamentInvite)
        #expect(invite.tournamentId == Laurel.tournamentID && invite.tournamentName == "Kickers Cup")
        #expect(invite.type == .football && invite.format == .singleElimination && invite.teamSize == 5 && invite.isTeam)
        #expect(invite.inviterUserId == "sub-2" && invite.inviterName == "Noor" && invite.status == .pending)
        #expect(invite.expiresAt == APIJSONCoding.parseInstant("2026-10-09T10:00:00Z") && invite.respondedAt == nil)
        #expect(invite.isOpen(now: Self.now) && invite.statusCaption(now: Self.now) == nil)
        #expect(item.caption == "Noor invited you to Kickers Cup")
        #expect(invite.details == "Football · Single elimination · Teams of 5")
    }

    @Test func theMatchReminderDecodesWithAndWithoutAPlace() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: Laurel.matchReminder)

        #expect(item.id == Laurel.reminderItemID && item.kind == .matchReminder && item.isVisible)
        let reminder = try #require(item.matchReminder)
        #expect(reminder.tournamentId == Laurel.tournamentID && reminder.tournamentName == "Kickers Cup")
        #expect(reminder.matchId == "r01p002" && reminder.opponentName == "Riverside Rovers")
        #expect(reminder.scheduledAt == APIJSONCoding.parseInstant("2026-10-18T12:00:00Z"))
        #expect(reminder.locationName == "Tempelhofer Feld")
        #expect(reminder.destination == TournamentDestination(id: Laurel.tournamentID, name: "Kickers Cup", matchID: "r01p002"))
        #expect(item.caption == "Match reminder · Kickers Cup")

        let bare = try ContractSamples.decode(InboxItem.self, from: Laurel.matchReminderWithoutPlace)
        #expect(bare.matchReminder?.locationName == nil && bare.isVisible)
    }

    /// The individual accept enters the caller and names the entry; the team accept flips the item alone.
    @Test func theAcceptAnswersCarryTheTournamentAndNoGroup() throws {
        let individual = try ContractSamples.decode(InviteAcceptance.self, from: Laurel.inviteAcceptedIndividual)
        #expect(individual.group == nil)
        #expect(individual.item.tournamentInvite?.status == .accepted)
        #expect(individual.item.tournamentInvite?.respondedAt == APIJSONCoding.parseInstant("2026-09-25T10:01:00Z"))
        let tournament = try #require(individual.tournament)
        #expect(tournament.id == Laurel.tournamentID && tournament.myEntryId == "01K6QZ3F8X2M4N6P8R0T2V4W6Y")
        #expect(tournament.hasEntered && tournament.entryCount == 1 && tournament.group?.id == "g1")

        let team = try ContractSamples.decode(InviteAcceptance.self, from: Laurel.inviteAcceptedTeam)
        #expect(team.group == nil && team.tournament?.myEntryId == nil && team.item.tournamentInvite?.status == .accepted)
        #expect(team.tournament?.hasEntered == false, "the player picks or names a team on the detail")
    }

    @Test func theInviteRoutesDecode() throws {
        let sent = try ContractSamples.decode(SentInvite.self, from: Laurel.sentInvite)
        #expect(sent.id == Laurel.inviteItemID && sent.tournamentId == Laurel.tournamentID && sent.groupId == nil)
        #expect(sent.inviteeUserId == "sub-2" && sent.inviteeName == "Noor" && sent.status == .pending)
        #expect(sent.expiresAt == APIJSONCoding.parseInstant("2026-10-18T12:00:00Z"))

        let page = try ContractSamples.decode(Page<InviteCandidate>.self, from: Laurel.invitees)
        #expect(page.items.map(\.displayName) == ["Noor", "Jonas"] && page.nextCursor == nil)
        #expect(page.items[0].via == .group && page.items[0].viaName == "Kickers Cup" && page.items[0].isInvited)
        #expect(page.items[1].via == .event && !page.items[1].isInvited)
    }

    @Test func theRoomEventsDecode() throws {
        let changed = try ContractSamples.decode(RealtimeEnvelope.self, from: Laurel.tournamentChangedEnvelope)
        guard case .tournamentChanged(let change) = changed else { Issue.record("expected .tournamentChanged"); return }
        #expect(change.tournamentId == "t1" && change.status == .inProgress && change.entryCount == 5 && change.channelEpoch == 3)
        #expect(change.updatedAt == APIJSONCoding.parseInstant("2026-09-25T10:00:00Z"))
        #expect(changed.groupID == "t1" && changed.channelEpoch == 3, "the room is the tournament")

        let bare = try ContractSamples.decode(RealtimeEnvelope.self, from: Laurel.tournamentChangedEnvelopeWithoutUpdate)
        guard case .tournamentChanged(let cancelled) = bare else { Issue.record("expected .tournamentChanged"); return }
        #expect(cancelled.status == .cancelled && cancelled.updatedAt == nil)

        let updated = try ContractSamples.decode(RealtimeEnvelope.self, from: Laurel.matchUpdatedEnvelope)
        guard case .matchUpdated(let match) = updated else { Issue.record("expected .matchUpdated"); return }
        #expect(match.id == "r01p002" && match.tournamentId == "t1" && match.status == .scheduled)
        #expect(match.scheduledAt == APIJSONCoding.parseInstant("2026-09-25T10:00:00Z") && match.nextSlot == .b)
        #expect(updated.groupID == "t1" && updated.channelEpoch == nil)
    }

    /// The helpers the inbox cards and the mock read, over the fixture builders.
    @Test func theItemsAnswerAndCaptionLikeTheGroupInvite() {
        let invite = InboxItem.tournamentInvite()
        let accepted = invite.responding(.accepted, at: Self.now)
        #expect(accepted.tournamentInvite?.status == .accepted && accepted.tournamentInvite?.respondedAt == Self.now)
        #expect(accepted.tournamentInvite?.statusCaption(now: Self.now) == "You joined" && accepted.kind == .tournamentInvite)
        #expect(invite.responding(.declined, at: Self.now).tournamentInvite?.statusCaption(now: Self.now) == "Declined")
        #expect(invite.inviteAnswer?.status == .pending && InboxItem.matchReminder().inviteAnswer == nil)
        #expect(InboxItem.matchReminder().responding(.accepted, at: Self.now) == InboxItem.matchReminder(),
                "a reminder has no answer")
        #expect(InboxItem.tournamentInvite(expiresAt: Self.now).tournamentInvite?.statusCaption(now: Self.now) == "Expired")
        #expect(InboxItem.tournamentInvite(teamSize: 1).tournamentInvite?.details == "Padel · Round robin · Individuals")
        #expect(InboxItemKind(wireName: "match_reminder") == .matchReminder)
        #expect(InboxItemKind.tournamentInvite.wireName == "tournament_invite")
        #expect(InboxItem.matchReminder().caption == "Match reminder · Tuesday Table Tennis")
    }

    /// The match reminder names the day, the clock time and the distance like the game reminder does.
    @Test func theMatchReminderNamesTheDayTheTimeAndTheDistance() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        let now = Date.now
        let noonToday = calendar.startOfDay(for: now).addingTimeInterval(12 * 3_600)
        let reminder = try #require(InboxItem.matchReminder(scheduledAt: noonToday).matchReminder)

        let distance = noonToday.formatted(.relative(presentation: .named))
        #expect(reminder.startsAtCaption(now: now, calendar: calendar) == "Today, 12:00 · \(distance)")
    }
}
