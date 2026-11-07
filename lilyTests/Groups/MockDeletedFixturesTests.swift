import Foundation
import Testing
@testable import lily

/// The `-mock-deleted-user` fixtures (the relocation contract): a chat line whose sender deleted their account, a past
/// game hosted by a deleted user, and a tournament entry of one stamped by the deletion job — each flagged on the wire
/// shape the backend flags, and absent without the launch argument.
@MainActor
struct MockDeletedFixturesTests {
    private let identity = FakeIdentityProvider(currentUserID: "u-1")
    private let logger = SpyLogger()

    @Test func theKickersRoomCarriesADeletedSendersLineOnlyUnderTheFlag() async throws {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        let chat = MockChatRepository(groups: groups,
                                      transport: MockRealtimeTransport(logger: logger),
                                      identity: identity,
                                      logger: logger,
                                      attachments: MockAttachmentStore(),
                                      autoReplies: false,
                                      deletedSender: true)
        let page = try await chat.newest(groupID: MockGroupFixtures.kickersID)
        let row = try #require(page.items.last)
        #expect(row.deleted == true && row.senderName == AppConfig.DisplayName.backendDefault)
        #expect(!row.isDeleted, "the sender's tombstone, never the message's own deletion")
        #expect(row.id > page.items.dropLast().last.map(\.id) ?? "", "the appended row sorts after every fixture row")

        let plainGroups = MockGroupRepository(identity: identity, logger: logger)
        let plain = MockChatRepository(groups: plainGroups,
                                       transport: MockRealtimeTransport(logger: logger),
                                       identity: identity,
                                       logger: logger,
                                       attachments: MockAttachmentStore(),
                                       autoReplies: false)
        let plainPage = try await plain.newest(groupID: MockGroupFixtures.kickersID)
        #expect(plainPage.items.allSatisfy { $0.deleted == nil }, "without the flag no fixture is tombstoned")
    }

    @Test func aPastGameHostedByADeletedUserJoinsTheEventFixtures() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = MockEventRepository(now: now, identity: identity, logger: logger, deletedHost: true)
        let event = try await repository.event(id: "mock-event-deleted-host")
        #expect(event.deleted == true && event.hostName == AppConfig.DisplayName.backendDefault)
        #expect(event.startsAt < now, "the job cancels upcoming hosted games, so only a past one can keep its host")

        let plain = MockEventRepository(now: now, identity: identity, logger: logger)
        await #expect(throws: AppError.eventNotFound) { try await plain.event(id: "mock-event-deleted-host") }
    }

    @Test func theTableTennisEntryOfOneIsStampedLikeTheDeletionJobLeavesIt() async throws {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        let repository = MockTournamentRepository(groups: groups, identity: identity, logger: logger, deletedFixtures: true)
        let detail = try await repository.tournament(id: MockTournamentFixtures.tableTennisID)
        let deletedID = MockGroupFixtures.memberID(for: MockTournamentFixtures.deletedPlayer)
        let entry = try #require(detail.entries.first { $0.contains(userID: deletedID) })
        #expect(entry.name == AppConfig.DisplayName.backendDefault, "a solo entry's name is the player's own")
        let member = try #require(entry.members.first { $0.userId == deletedID })
        #expect(member.deleted == true && member.displayName == AppConfig.DisplayName.backendDefault)
        #expect(detail.entries.filter { !$0.contains(userID: deletedID) }
            .allSatisfy { entry in entry.members.allSatisfy { $0.deleted == nil } }, "everyone else is untouched")
    }
}
