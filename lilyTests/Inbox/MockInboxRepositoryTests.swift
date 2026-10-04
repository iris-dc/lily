import Foundation
import Testing
@testable import lily

/// The mock's behaviour the UI tests and previews lean on: the two fixture items and the backend's refusals.
@MainActor
struct MockInboxRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let climbing = MockGroupFixtures.climbingID
    private let inviteID = MockInboxFixtures.inviteID
    private let reminderID = MockInboxFixtures.reminderID

    private func makeRepositories(now: @escaping () -> Date) -> (groups: MockGroupRepository, inbox: MockInboxRepository) {
        let groups = MockGroupRepository(identity: identity, logger: logger, now: now)
        let tournaments = MockTournamentRepository(groups: groups, identity: identity, logger: logger, now: now)
        let inbox = MockInboxRepository(groups: groups, tournaments: tournaments, identity: identity, logger: logger, now: now)
        return (groups, inbox)
    }

    private func makeRepositories() -> (groups: MockGroupRepository, inbox: MockInboxRepository) {
        makeRepositories { now }
    }

    @Test func theFixturesAreATournamentInviteAGameReminderAMatchReminderThenNoorsInviteIntoClimbingBuddies() async throws {
        let (_, inbox) = makeRepositories()

        let page = try await inbox.page(before: nil, limit: AppConfig.Inbox.pageSize)

        let ids = [MockInboxFixtures.tournamentInviteID, reminderID, MockInboxFixtures.matchReminderID, inviteID]
        #expect(page.items.map(\.id) == ids)
        #expect(!page.hasMore && page.nextBefore == nil && page.lastReadId == nil && page.items.allSatisfy(\.isVisible))
        #expect(page.items.map(\.id) == page.items.map(\.id).sorted())
        #expect(page.items.map(\.createdAt) == page.items.map(\.createdAt).sorted(), "ids follow time")
        let event = try #require(MockEventFixtures.make(now: now, count: 1).first)
        let reminder = try #require(page.items[1].reminder)
        #expect(reminder.eventId == event.id && reminder.title == event.title)
        #expect(reminder.locationName == event.locationName && reminder.groupName == "Kreuzberg Kickers")
        #expect(reminder.startsAt == now.addingTimeInterval(AppConfig.Inbox.mockReminderLead))
        let invite = try #require(page.items[3].invite)
        #expect(invite.groupId == climbing && invite.groupName == "Climbing Buddies" && invite.groupVisibility == .private)
        #expect(invite.inviterName == "Noor" && invite.inviterUserId == MockGroupFixtures.memberID(for: "Noor"))
        #expect(invite.status == .pending && invite.isOpen(now: now))
    }

    @Test func acceptingAdmitsIntoClimbingBuddiesAndReplaysTheSameShape() async throws {
        let (groups, inbox) = makeRepositories()

        let acceptance = try await inbox.accept(itemID: inviteID)

        #expect(acceptance.group?.id == climbing && acceptance.group?.role == .member && acceptance.group?.memberCount == 10)
        #expect(acceptance.tournament == nil)
        #expect(acceptance.item.id == inviteID && acceptance.item.invite?.status == .accepted)
        #expect(acceptance.item.invite?.respondedAt == now)
        #expect(try await groups.group(id: climbing).isMember, "the group mock admitted the caller")
        #expect(try await inbox.accept(itemID: inviteID) == acceptance, "a repeat changes nothing")
        #expect(try await inbox.page(before: nil, limit: 50).items[3].invite?.status == .accepted)
        #expect(logger.messages(in: .inbox, at: .info).contains("Mock invite \(inviteID) accepted into group \(climbing)"))
        await #expect(throws: AppError.inviteNotPending) { try await inbox.decline(itemID: inviteID) }
    }

    @Test func decliningFlipsTheStatusAndRefusesALaterAccept() async throws {
        let (groups, inbox) = makeRepositories()

        let declined = try await inbox.decline(itemID: inviteID)

        #expect(declined.invite?.status == .declined && declined.invite?.respondedAt == now)
        #expect(try await inbox.decline(itemID: inviteID) == declined, "a repeat answers the same item")
        await #expect(throws: AppError.inviteNotPending) { try await inbox.accept(itemID: inviteID) }
        await #expect(throws: AppError.groupNotFound) { try await groups.group(id: climbing) }
    }

    /// Accepting Noor's invite enters the caller into the Padel Open (the tournament mock's join, so the room follows)
    /// and answers the tournament with the entry; a repeat changes nothing; a decline afterwards is refused.
    @Test func acceptingTheTournamentInviteEntersThePadelOpen() async throws {
        let (groups, inbox) = makeRepositories()
        let tournamentInviteID = MockInboxFixtures.tournamentInviteID
        let padelOpen = MockTournamentFixtures.padelOpenID

        let acceptance = try await inbox.accept(itemID: tournamentInviteID)

        #expect(acceptance.group == nil && acceptance.item.id == tournamentInviteID)
        #expect(acceptance.item.tournamentInvite?.status == .accepted && acceptance.item.tournamentInvite?.respondedAt == now)
        let tournament = try #require(acceptance.tournament)
        #expect(tournament.id == padelOpen && tournament.hasEntered && tournament.entryCount == 5)
        #expect(try await groups.group(id: padelOpen).isMember, "the room admitted the caller")
        #expect(try await inbox.accept(itemID: tournamentInviteID) == acceptance, "a repeat changes nothing")
        #expect(logger.messages(in: .inbox, at: .info)
            .contains("Mock invite \(tournamentInviteID) accepted into tournament \(padelOpen)"))
        await #expect(throws: AppError.inviteNotPending) { try await inbox.decline(itemID: tournamentInviteID) }
    }

    @Test func decliningTheTournamentInviteFlipsItAndRefusesALaterAccept() async throws {
        let (_, inbox) = makeRepositories()
        let tournamentInviteID = MockInboxFixtures.tournamentInviteID

        let declined = try await inbox.decline(itemID: tournamentInviteID)

        #expect(declined.tournamentInvite?.status == .declined && declined.tournamentInvite?.respondedAt == now)
        await #expect(throws: AppError.inviteNotPending) { try await inbox.accept(itemID: tournamentInviteID) }
    }

    @Test func remindersAndUnknownIdsAreNothingToAnswer() async {
        let (_, inbox) = makeRepositories()

        await #expect(throws: AppError.inviteNotPending) { try await inbox.accept(itemID: reminderID) }
        await #expect(throws: AppError.inviteNotPending) { try await inbox.decline(itemID: "nope") }
    }

    @Test func anInviteExpiresAfterItsWeek() async {
        var clock = now
        let (_, inbox) = makeRepositories { clock }

        clock = now.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry + 1)

        await #expect(throws: AppError.inviteExpired) { try await inbox.accept(itemID: inviteID) }
    }

    @Test func theReadMarkerIsMonotonicAndComesBackWithThePage() async throws {
        let (_, inbox) = makeRepositories()

        #expect(try await inbox.markRead(itemID: inviteID) == inviteID)
        #expect(try await inbox.markRead(itemID: reminderID) == inviteID, "an older id leaves the marker where it was")
        #expect(try await inbox.page(before: nil, limit: 50).lastReadId == inviteID)
    }

    @Test func pagingFollowsTheIds() async throws {
        let (_, inbox) = makeRepositories()

        let newest = try await inbox.page(before: nil, limit: 1)
        #expect(newest.items.map(\.id) == [inviteID] && newest.hasMore && newest.nextBefore == inviteID)

        let earlier = try await inbox.page(before: inviteID, limit: 3)
        #expect(earlier.items.map(\.id) == [MockInboxFixtures.tournamentInviteID, reminderID, MockInboxFixtures.matchReminderID])
        #expect(!earlier.hasMore && earlier.nextBefore == nil)
    }

    @Test func guestsHaveNoInbox() async {
        identity.currentUserID = nil
        let (_, inbox) = makeRepositories()

        await #expect(throws: AppError.sessionExpired) { try await inbox.page(before: nil, limit: 50) }
        await #expect(throws: AppError.sessionExpired) { try await inbox.markRead(itemID: inviteID) }
        await #expect(throws: AppError.sessionExpired) { try await inbox.accept(itemID: inviteID) }
    }
}
