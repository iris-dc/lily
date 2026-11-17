import Foundation
import Testing
@testable import lily

/// Laurel's strict JSON for the event invites (the event members of `ContractSamples`) decoded with the app's
/// conventions, and what the screens read off it; the tournament contract tests' twin.
struct EventInboxContractTests {
    /// Before the fixture invite expires (2026-11-29), so it is still open.
    private static let now = Date(timeIntervalSince1970: 1_795_000_000)

    @Test func theEventInviteDecodesEveryField() throws {
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.eventInviteItem)

        #expect(item.id == ContractSamples.eventInviteItemID && item.kind == .eventInvite && item.isVisible)
        #expect(item.invite == nil && item.reminder == nil && item.tournamentInvite == nil && item.matchReminder == nil)
        let invite = try #require(item.eventInvite)
        #expect(invite.eventId == "evt_03" && invite.title == "Sunset 5-a-side" && invite.type == .football)
        #expect(invite.startsAt == APIJSONCoding.parseInstant("2026-11-16T18:00:00Z"))
        #expect(invite.locationName == "Riverside Pitch 2")
        #expect(invite.inviterUserId == "seed-noor" && invite.inviterName == "Noor" && invite.status == .pending)
        #expect(invite.expiresAt == APIJSONCoding.parseInstant("2026-11-29T12:00:00Z") && invite.respondedAt == nil)
        #expect(invite.isOpen(now: Self.now) && invite.statusCaption(now: Self.now) == nil)
        #expect(item.caption == "Noor invited you to Sunset 5-a-side")
    }

    /// The detail line is the type and the shared time caption, judged against the given clock.
    @Test func theDetailLineNamesTheTypeAndTheStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let item = try ContractSamples.decode(InboxItem.self, from: ContractSamples.eventInviteItem)
        let invite = try #require(item.eventInvite)

        let details = invite.details(now: Self.now, calendar: calendar)

        #expect(details.hasPrefix("Football · "))
        #expect(details.contains(invite.startsAtCaption(now: Self.now, calendar: calendar)))
    }

    /// A type a newer backend added decodes; the card still draws.
    @Test func anInviteOfAnUnseenTypeDecodes() throws {
        let json = ContractSamples.eventInviteItem.replacingOccurrences(of: #""type":"football""#, with: #""type":"sepak""#)
        let item = try ContractSamples.decode(InboxItem.self, from: json)
        #expect(item.isVisible && item.eventInvite?.type == .unknown("sepak"))
    }

    /// The accept answers the item flipped and the event joined, with the epoch mirror; no group or tournament.
    @Test func theAcceptAnswerCarriesTheEventAlone() throws {
        let acceptance = try ContractSamples.decode(InviteAcceptance.self, from: ContractSamples.inviteAcceptedEvent)

        #expect(acceptance.group == nil && acceptance.tournament == nil)
        #expect(acceptance.item.eventInvite?.status == .accepted)
        #expect(acceptance.item.eventInvite?.respondedAt == APIJSONCoding.parseInstant("2026-11-15T12:01:00Z"))
        let event = try #require(acceptance.event)
        #expect(event.id == "evt_03" && event.participates && event.participantCount == 7)
        #expect(event.channelEpoch == 2 && event.group?.id == "7b1c2d3e-4f50-4a6b-8c9d-0e1f2a3b4c5d")
    }

    @Test func theSentInviteDecodesWithTheEventKeyAlone() throws {
        let sent = try ContractSamples.decode(SentInvite.self, from: ContractSamples.sentEventInvite)
        #expect(sent.id == ContractSamples.eventInviteItemID && sent.eventId == "evt_03")
        #expect(sent.groupId == nil && sent.tournamentId == nil)
        #expect(sent.inviteeUserId == "seed-noor" && sent.inviteeName == "Noor" && sent.status == .pending)
    }

    /// A payload from before rooms carries no `channelEpoch` and reads as 1.
    @Test func anEventWithoutTheEpochMirrorReadsAsOne() throws {
        let event = try ContractSamples.decode(SportEvent.self, from: ContractSamples.groupedEvent)
        #expect(event.channelEpoch == 1)
    }
}
