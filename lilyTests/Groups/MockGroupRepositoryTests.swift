import Foundation
import Testing
@testable import lily

/// The mock's behaviour the UI tests and previews lean on: the fixtures of plan 8.5 and the backend's refusals.
@MainActor
struct MockGroupRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()

    private func makeRepository() -> MockGroupRepository {
        MockGroupRepository(identity: identity, logger: logger)
    }

    /// The three joined groups and the conversation with Marta, most recently active first, as the backend orders Mine.
    @Test func mineHoldsTheJoinedGroupsAndTheConversationMostRecentlyActiveFirst() async throws {
        let mine = try await makeRepository().groups(in: .mine, cursor: nil)

        #expect(mine.items.map(\.name) == ["Kreuzberg Kickers", "Marta", "Tempelhof Runners", "Sunday Padel Crew"])
        #expect(mine.items.map(\.role) == [.member, .member, .admin, .owner])
        #expect(mine.items.map(\.hasUnread) == [true, true, false, false])
        #expect(mine.items.map(\.isDirect) == [false, true, false, false])
        #expect(mine.nextCursor == nil)
    }

    /// The fixture conversation is shaped like the backend's: kind `direct`, Marta as the counterpart and the name,
    /// private and full at two, no powers, `member`, unread, its roster the two of them. Starting a conversation with
    /// her answers it; with anyone else a new one is created under their id.
    @Test func theMartaConversationIsAFixtureThatStartDirectReplays() async throws {
        let repository = makeRepository()
        let marta = MockGroupFixtures.conversationCounterpart

        let conversation = try await repository.group(id: MockGroupFixtures.martaConversationID)
        #expect(conversation.isDirect && conversation.counterpart == marta && conversation.name == "Marta")
        #expect(conversation.visibility == .private && conversation.memberCount == 2 && conversation.maxMembers == 2)
        #expect(!conversation.membersCanCreateEvents && !conversation.membersCanInvite && conversation.role == .member)
        #expect(conversation.hasUnread && conversation.lastMessageId == MockChatFixtures.newestMessageID(for: conversation.id))
        #expect(try await repository.members(id: conversation.id).map(\.displayName) == ["Marta", "You"])

        #expect(repository.startDirect(with: marta.userId, name: marta.displayName) == conversation)
        #expect(logger.messages(in: .groups, at: .info).contains("Mock conversation \(conversation.id) replayed"))
        let jonas = MockGroupFixtures.memberID(for: "Jonas")
        let started = repository.startDirect(with: jonas, name: "Jonas")
        #expect(started.isDirect && started.counterpart == Counterpart(userId: jonas, displayName: "Jonas"))
        #expect(started.id == MockGroupFixtures.directConversationID(for: jonas) && started.id != conversation.id)
        #expect(try await repository.groups(in: .mine, cursor: nil).items.count(where: \.isDirect) == 2)
    }

    @Test func discoverListsPublicGroupsNewestFirstAndSearchesByPrefix() async throws {
        let repository = makeRepository()

        let all = try await repository.groups(in: .discover(query: nil, type: nil), cursor: nil).items
        #expect(all.map(\.name) == ["Spree Volley", "Tempelhof Runners", "Kreuzberg Kickers", "Berlin Basketball"])
        #expect(all.count == AppConfig.Groups.mockGroupCount - 2, "the two private groups never appear")

        let searched = try await repository.groups(in: .discover(query: "ber", type: nil), cursor: nil).items
        #expect(searched.map(\.name) == ["Berlin Basketball"])

        let typed = try await repository.groups(in: .discover(query: nil, type: .football), cursor: nil).items
        #expect(typed.map(\.name) == ["Kreuzberg Kickers"])
    }

    /// A private group is not there for an outsider, on reads and writes alike.
    @Test func privateGroupsAnswerNotFoundToOutsiders() async throws {
        let repository = makeRepository()

        await #expect(throws: AppError.groupNotFound) { try await repository.group(id: MockGroupFixtures.climbingID) }
        await #expect(throws: AppError.groupNotFound) { try await repository.join(id: MockGroupFixtures.climbingID) }
        #expect(try await repository.group(id: MockGroupFixtures.padelID).role == .owner, "the owner reads their private group")
    }

    @Test func joinAddsTheCallerOnceAndRefusesAFullGroup() async throws {
        let repository = makeRepository()

        let joined = try await repository.join(id: MockGroupFixtures.basketballID)
        #expect(joined.role == .member && joined.memberCount == 59)
        #expect(try await repository.join(id: MockGroupFixtures.basketballID).memberCount == 59, "a replay changes nothing")
        #expect(try await repository.groups(in: .mine, cursor: nil).items.count == 5)
        #expect(logger.messages(in: .groups, at: .info).contains("Joined group \(MockGroupFixtures.basketballID) (public)"))

        await #expect(throws: AppError.groupFull) { try await repository.join(id: MockGroupFixtures.volleyID) }
    }

    @Test func leaveRefusesTheOwnerAndBumpsTheEpochForEveryoneElse() async throws {
        let repository = makeRepository()

        let left = try await repository.leave(id: MockGroupFixtures.kickersID)
        #expect(!left.isMember && left.memberCount == 33 && left.channelEpoch == 2)
        await #expect(throws: AppError.notAMember) { try await repository.leave(id: MockGroupFixtures.kickersID) }
        await #expect(throws: AppError.ownerCannotLeave) { try await repository.leave(id: MockGroupFixtures.padelID) }
    }

    @Test func createReplaysTheSameIdAndTheOwnerCanEditAndDelete() async throws {
        let repository = makeRepository()
        let draft = GroupDraft.fixture()

        let created = try await repository.create(draft)
        #expect(created.id == draft.clientId && created.role == .owner && created.memberCount == 1)
        #expect(try await repository.create(draft) == created)
        #expect(logger.messages(in: .groups, at: .info).contains("Group created \(draft.clientId) (public)"))

        var edited = draft
        edited.name = "Renamed"
        #expect(try await repository.update(id: created.id, edited).name == "Renamed")
        #expect(try await repository.delete(id: created.id).isDeleted)
        await #expect(throws: AppError.groupNotFound) { try await repository.group(id: created.id) }
    }

    @Test func rolesGateEditingAndDeleting() async {
        let repository = makeRepository()

        await #expect(throws: AppError.insufficientRole) {
            try await repository.update(id: MockGroupFixtures.kickersID, .fixture())
        }
        await #expect(throws: AppError.insufficientRole) { try await repository.delete(id: MockGroupFixtures.runnersID) }
        await #expect(throws: AppError.insufficientRole) { try await repository.bans(id: MockGroupFixtures.kickersID) }
    }

    /// The roster: owner first, then admins, then by join time, with the caller's own row in their role.
    @Test func membersListTheRosterWithTheCaller() async throws {
        let repository = makeRepository()

        let kickers = try await repository.members(id: MockGroupFixtures.kickersID)
        #expect(kickers.map(\.role) == [.owner, .admin, .member, .member, .member])
        #expect(kickers.last?.userId == TestFixtures.user.id && kickers.last?.displayName == "You")

        let padel = try await repository.members(id: MockGroupFixtures.padelID)
        #expect(padel.first?.userId == TestFixtures.user.id && padel.first?.role == .owner)
        #expect(!padel.contains { $0.role == .banned })
        #expect(try await repository.bans(id: MockGroupFixtures.padelID).map(\.displayName) == ["Priya"])

        await #expect(throws: AppError.groupNotFound) { try await repository.members(id: MockGroupFixtures.climbingID) }
    }

    /// A public group's roster answers any signed-in caller, without a row for someone who is not in; a guest gets the
    /// backend's 401; a private group stays out of reach.
    @Test func publicRostersAnswerOutsidersWithoutACallerRow() async throws {
        let repository = makeRepository()

        let basketball = try await repository.members(id: MockGroupFixtures.basketballID)
        #expect(basketball.map(\.displayName) == ["Dev", "Marta"])
        #expect(!basketball.contains { $0.userId == TestFixtures.user.id })

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.members(id: MockGroupFixtures.basketballID) }
    }

    /// The marker is monotonic like the backend's, and Mine reflects it: a room read here is read on the next load.
    @Test func markReadMovesTheMarkerForwardOnlyAndClearsTheUnreadFlag() async throws {
        let repository = makeRepository()
        let kickers = MockGroupFixtures.kickersID
        let newest = MockChatFixtures.newestMessageID(for: kickers)
        let older = MockChatFixtures.lastReadMessageID(for: kickers)

        #expect(try repository.markRead(id: kickers, messageID: newest) == newest)
        #expect(try await repository.group(id: kickers).hasUnread == false)
        #expect(try await repository.groups(in: .mine, cursor: nil).items.filter(\.hasUnread).map(\.id)
                == [MockGroupFixtures.martaConversationID], "only the conversation's unread lines are left")

        #expect(try repository.markRead(id: kickers, messageID: older) == newest)
        #expect(try await repository.group(id: kickers).membership?.lastReadMessageId == newest)
        #expect(throws: AppError.notAMember) { try repository.markRead(id: MockGroupFixtures.basketballID, messageID: newest) }
    }

    /// What a mock event hosted in one of these groups carries as its badge.
    @Test func refNamesTheGroupAndIsNilForAnUnknownId() throws {
        let kickers = try #require(MockGroupFixtures.ref(for: MockGroupFixtures.kickersID))
        let padel = try #require(MockGroupFixtures.ref(for: MockGroupFixtures.padelID))

        let expected = EventGroupRef(id: MockGroupFixtures.kickersID,
                                     name: "Kreuzberg Kickers",
                                     visibility: .public,
                                     isDeleted: false)
        #expect(kickers == expected)
        #expect(padel.visibility == .private && !padel.isLinkable)
        #expect(MockGroupFixtures.make(now: .now).map(\.ref).contains(kickers))
        #expect(MockGroupFixtures.ref(for: "nowhere") == nil)
    }

    @Test func adminsRemoveAndBanMembersOwnersPromote() async throws {
        let repository = makeRepository()
        let sam = MockGroupFixtures.memberID(for: "Sam")
        let aiko = MockGroupFixtures.memberID(for: "Aiko")
        let tom = MockGroupFixtures.memberID(for: "Tom")

        let afterRemoval = try await repository.remove(id: MockGroupFixtures.runnersID, userID: sam)
        #expect(afterRemoval.memberCount == 11 && afterRemoval.channelEpoch == 2 && afterRemoval.role == .admin)
        await #expect(throws: AppError.insufficientRole) {
            try await repository.remove(id: MockGroupFixtures.runnersID, userID: aiko)
        }

        let noor = MockGroupFixtures.memberID(for: "Noor")
        let banned = try await repository.setRole(id: MockGroupFixtures.runnersID, userID: noor, .banned)
        #expect(banned.role == .banned)
        #expect(try await repository.bans(id: MockGroupFixtures.runnersID).map(\.userId) == [banned.userId])
        try await repository.unban(id: MockGroupFixtures.runnersID, userID: banned.userId)
        #expect(try await repository.bans(id: MockGroupFixtures.runnersID).isEmpty)

        await #expect(throws: AppError.insufficientRole) {
            try await repository.setRole(id: MockGroupFixtures.runnersID, userID: aiko, .admin)
        }
        #expect(try await repository.setRole(id: MockGroupFixtures.padelID, userID: tom, .member).role == .member)
    }
}
