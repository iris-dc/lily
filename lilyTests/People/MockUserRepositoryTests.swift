import Foundation
import Testing
@testable import lily

/// Profiles from the fixture rosters and the mock's direct conversations, as previews and UI tests see them.
@MainActor
struct MockUserRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let groups: MockGroupRepository
    private let repository: MockUserRepository
    private let marta = MockGroupFixtures.memberID(for: "Marta")
    private let jonas = MockGroupFixtures.memberID(for: "Jonas")

    init() {
        groups = MockGroupRepository(identity: identity, logger: logger)
        repository = MockUserRepository(groups: groups, identity: identity, logger: logger)
    }

    /// Marta is on the Kickers and the Basketball rosters; the caller is in Kickers only, so that is what they share.
    @Test func aProfileNamesThePersonAndTheGroupsTheCallerSharesWithThem() async throws {
        let profile = try await repository.profile(userID: marta)

        #expect(profile.userId == marta && profile.displayName == "Marta")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers"], "the conversation with her is no group in common")
        #expect(profile.sharedGroups.first?.type == .football && profile.sharedGroups.first?.memberCount == 34)
    }

    /// Priya is banned from Sunday Padel Crew and a member of Climbing Buddies, which the caller is not in.
    @Test func bannedRowsAndGroupsTheCallerIsNotInDoNotCount() async throws {
        let profile = try await repository.profile(userID: MockGroupFixtures.memberID(for: "Priya"))

        #expect(profile.displayName == "Priya" && profile.sharedGroups.isEmpty)
    }

    @Test func theOwnProfileListsTheCallersGroupsByName() async throws {
        let profile = try await repository.profile(userID: TestFixtures.user.id)

        #expect(profile.displayName == "You")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers", "Sunday Padel Crew", "Tempelhof Runners"])
    }

    @Test func unknownPeopleAreNotFoundAndGuestsAreRefused() async {
        await #expect(throws: AppError.userNotFound) { try await repository.profile(userID: "nobody") }
        await #expect(throws: AppError.userNotFound) { try await repository.startConversation(with: "nobody") }

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.profile(userID: marta) }
        await #expect(throws: AppError.sessionExpired) { try await repository.startConversation(with: marta) }
    }

    /// One conversation per pair: a private two-member group of kind `direct` named after the person, the same one on
    /// every call, in Mine with the caller as a member, its roster naming the person, and never a group in common.
    @Test func startConversationCreatesTheDirectGroupOnceAndAnswersItAgain() async throws {
        let conversation = try await repository.startConversation(with: jonas)

        #expect(conversation.id == MockGroupFixtures.directConversationID(for: jonas) && conversation.name == "Jonas")
        #expect(conversation.isDirect && conversation.counterpart == Counterpart(userId: jonas, displayName: "Jonas"))
        #expect(conversation.visibility == .private && conversation.memberCount == 2 && conversation.maxMembers == 2)
        #expect(conversation.role == .member && !conversation.membersCanCreateEvents && !conversation.membersCanInvite)
        #expect(try await repository.startConversation(with: jonas) == conversation)
        #expect(try await groups.groups(in: .mine, cursor: nil, near: nil).items.contains(conversation))
        #expect(try await groups.members(id: conversation.id).map(\.displayName) == ["Jonas", "You"])
        #expect(try await repository.profile(userID: jonas).sharedGroups.map(\.name) == ["Kreuzberg Kickers"])
        #expect(logger.messages(in: .groups, at: .info).contains("Mock conversation \(conversation.id) created with \(jonas)"))
        await #expect(throws: AppError.conversationFailed) { try await repository.startConversation(with: TestFixtures.user.id) }
    }

    /// The fixtures already hold the conversation with Marta: a start with her answers that one, unread lines and all.
    @Test func startConversationWithMartaAnswersTheFixture() async throws {
        let conversation = try await repository.startConversation(with: marta)

        #expect(conversation.id == MockGroupFixtures.martaConversationID && conversation.hasUnread)
        #expect(conversation.counterpart == MockGroupFixtures.conversationCounterpart)
        #expect(try await groups.groups(in: .mine, cursor: nil, near: nil).items.count(where: \.isDirect) == 1)
    }
}
