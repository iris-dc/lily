import Foundation
import Testing
@testable import lily

/// The wire shapes of the inbox plan, section 2.1, decoded with the app's conventions, and the helpers the screens read.
struct InboxItemCodingTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func inviteDecodesEveryContractField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxInvite)

        #expect(item.id == ContractSamples.inboxInviteID && item.kind == .groupInvite && item.isVisible)
        #expect(item.createdAt == APIJSONCoding.parseInstant("2026-09-29T10:00:00Z") && item.reminder == nil)
        let invite = try #require(item.invite)
        #expect(invite.groupId == "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d" && invite.groupName == "Sunday Padel Crew")
        #expect(invite.groupVisibility == .private && invite.inviterUserId == "seed-marta" && invite.inviterName == "Marta")
        #expect(invite.status == .pending && invite.respondedAt == nil)
        #expect(invite.expiresAt == APIJSONCoding.parseInstant("2026-10-06T10:00:00Z"))
    }

    @Test func anAnsweredInviteCarriesItsAnswer() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxAcceptedInvite)
        #expect(item.invite?.status == .accepted)
        #expect(item.invite?.respondedAt == APIJSONCoding.parseInstant("2026-09-29T11:00:00Z"))
    }

    @Test func reminderDecodesEveryContractField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxReminder)

        #expect(item.id == ContractSamples.inboxReminderID && item.kind == .eventReminder && item.isVisible && item.invite == nil)
        let reminder = try #require(item.reminder)
        #expect(reminder.eventId == "evt_01J" && reminder.title == "Sunset 5-a-side")
        #expect(reminder.locationName == "Tempelhofer Feld" && reminder.groupName == "Kreuzberg Kickers")
        #expect(reminder.startsAt == APIJSONCoding.parseInstant("2026-09-29T18:30:00Z"))
    }

    /// A newer backend may add kinds; the page must still decode, and the item must stay out of sight.
    @Test func unknownKindsDecodeAndHide() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.inboxUnknownItem)
        #expect(item.kind == .unknown("poke") && item.kind.wireName == "poke")
        #expect(!item.isVisible && item.caption == nil && item.invite == nil && item.reminder == nil)
    }

    @Test func kindsEncodeAsTheirWireNames() throws {
        let data = try APIJSONCoding.makeEncoder().encode(InboxItem.reminder())
        let text = try #require(String(bytes: data, encoding: .utf8))
        #expect(text.contains(#""kind":"event_reminder""#))
        #expect(InboxItemKind(wireName: "group_invite") == .groupInvite && InboxItemKind.groupInvite.wireName == "group_invite")
    }

    @Test func pagesDecodeWithAndWithoutTheOptionalFields() throws {
        let page = try ContractSamples.decode(InboxPage.self, from: ContractSamples.inboxPage)
        #expect(page.items.map(\.kind) == [.groupInvite, .eventReminder] && page.hasMore)
        #expect(page.nextBefore == ContractSamples.inboxInviteID && page.lastReadId == ContractSamples.inboxInviteID)

        let minimal = try ContractSamples.decode(InboxPage.self, from: ContractSamples.minimalInboxPage)
        #expect(minimal.items.isEmpty && !minimal.hasMore && minimal.nextBefore == nil && minimal.lastReadId == nil)
    }

    @Test func theAnswersOfAcceptDeclineAndTheReadMarkerDecode() throws {
        let acceptance = try ContractSamples.decode(InviteAcceptance.self, from: ContractSamples.inviteAccepted)
        #expect(acceptance.item.invite?.status == .accepted && acceptance.group.id == acceptance.item.invite?.groupId)
        #expect(acceptance.group.role == .admin, "the group comes with the caller's membership")

        let declination = try ContractSamples.decode(InviteDeclination.self, from: ContractSamples.inviteDeclined)
        #expect(declination.item.invite?.status == .declined)

        let marker = try ContractSamples.decode(InboxReadMarker.self, from: ContractSamples.inboxReadMarker)
        #expect(marker.lastReadId == ContractSamples.inboxInviteID)
    }

    @Test func captionsNameTheInviterAndTheGame() {
        #expect(InboxItem.invite().caption == "Noor invited you to Climbing Buddies")
        #expect(InboxItem.reminder().caption == "Game reminder · Sunset 5-a-side")
    }

    /// The reminder names the day as the chat's chips do, then the clock time, then how far off the start is; the
    /// distance is judged against the wall clock, as the relative style is, so it is computed the same way here. A
    /// 24-hour locale, because `.shortened` puts a narrow no-break space before AM/PM that no literal here could show.
    @Test func theReminderNamesTheDayTheTimeAndTheDistance() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        let now = Date.now
        let noonToday = calendar.startOfDay(for: now).addingTimeInterval(12 * 3_600)
        let today = try #require(InboxItem.reminder(startsAt: noonToday).reminder)
        let yesterday = try #require(InboxItem.reminder(startsAt: noonToday.addingTimeInterval(-86_400)).reminder)

        let distance = noonToday.formatted(.relative(presentation: .named))
        #expect(today.startsAtCaption(now: now, calendar: calendar) == "Today, 12:00 · \(distance)")
        #expect(yesterday.startsAtCaption(now: now, calendar: calendar).hasPrefix("Yesterday, 12:00 · "))
    }

    /// Accept and Decline show while the invite is open; afterwards the card says what happened.
    @Test func inviteStatusFollowsTheAnswerAndTheClock() throws {
        let open = try #require(InboxItem.invite().invite)
        #expect(open.isOpen(now: Self.now) && open.statusCaption(now: Self.now) == nil)
        #expect(!open.isOpen(now: open.expiresAt) && open.statusCaption(now: open.expiresAt) == "Expired")

        let accepted = InboxItem.invite().responding(.accepted, at: Self.now)
        #expect(accepted.invite?.status == .accepted && accepted.invite?.respondedAt == Self.now)
        #expect(accepted.invite?.statusCaption(now: Self.now) == "You joined" && accepted.invite?.isOpen(now: Self.now) == false)
        #expect(InboxItem.invite(status: .declined).invite?.statusCaption(now: Self.now) == "Declined")
        #expect(InboxItem.reminder().responding(.accepted, at: Self.now) == InboxItem.reminder(), "a reminder has no answer")
    }

    @Test func theTimelineHidesUnknownKindsAndChipsEachDay() {
        let calendar = Calendar(identifier: .gregorian)
        let nextDay = Self.now.addingTimeInterval(86_400)
        let items: [InboxItem] = [.reminder(id: "1", createdAt: Self.now),
                                  .unknown(id: "2", createdAt: Self.now),
                                  .invite(id: "3", createdAt: nextDay),
                                  .invite(id: "4", createdAt: nextDay)]

        let rows = InboxTimeline.rows(items, calendar: calendar)

        #expect(rows.map(\.id) == ["day-\(Int(calendar.startOfDay(for: Self.now).timeIntervalSince1970))", "1",
                                   "day-\(Int(calendar.startOfDay(for: nextDay).timeIntervalSince1970))", "3", "4"])
        #expect(InboxTimeline.rows([.unknown()]).isEmpty, "an inbox of nothing this build can draw is empty")
    }
}
