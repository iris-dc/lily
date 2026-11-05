import Foundation
import Testing
@testable import lily

/// Profiles from the fixture rosters, the event and tournament mocks and the fixture bios, and the mock's direct
/// conversations, as previews and UI tests see them.
@MainActor
struct MockUserRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let groups: MockGroupRepository
    private let events: MockEventRepository
    private let tournaments: MockTournamentRepository
    private let profiles: MockProfileRepository
    private let repository: MockUserRepository
    private let marta = MockGroupFixtures.memberID(for: "Marta")
    private let jonas = MockGroupFixtures.memberID(for: "Jonas")

    init() {
        groups = MockGroupRepository(identity: identity, logger: logger)
        events = MockEventRepository(identity: identity, logger: logger)
        tournaments = MockTournamentRepository(groups: groups, identity: identity, logger: logger)
        profiles = MockProfileRepository(identity: identity, logger: logger)
        repository = MockUserRepository(groups: groups,
                                        events: events,
                                        tournaments: tournaments,
                                        profiles: profiles,
                                        identity: identity,
                                        logger: logger)
    }

    /// Marta is on the Kickers and the Basketball rosters; the caller is in Kickers only, so that is what they share.
    @Test func aProfileNamesThePersonAndTheGroupsTheCallerSharesWithThem() async throws {
        let profile = try await repository.profile(userID: marta)

        #expect(profile.userId == marta && profile.displayName == "Marta")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers"], "the conversation with her is no group in common")
        #expect(profile.sharedGroups.first?.type == .football && profile.sharedGroups.first?.memberCount == 34)
        #expect(profile.bio == "Padel on Sundays, football when it rains.")
    }

    /// Marta hosts Sunset 5-a-side, which the caller joined (the first fixture), and organises the table tennis the
    /// caller plays in; both are in Kickers Cup too, as is Priya, who has no fixture line about herself. Every game
    /// listed names the person.
    @Test func theHistoryIsTheGamesAndTournamentsBothAreIn() async throws {
        let profile = try await repository.profile(userID: marta)

        #expect(profile.sharedEvents.map(\.title).contains("Sunset 5-a-side"))
        #expect(profile.sharedEvents.map(\.startsAt) == profile.sharedEvents.map(\.startsAt).sorted(by: >), "latest first")
        for game in profile.sharedEvents {
            let participants = try await events.participants(eventId: game.id)
            #expect(participants.contains { $0.userId == marta }, "\(game.title) names Marta")
        }
        #expect(Set(profile.sharedTournaments.map(\.id)) == ["mock-tournament-table-tennis", "mock-tournament-kickers-cup"])
        #expect(profile.sharedTournaments.map(\.startsAt) == profile.sharedTournaments.map(\.startsAt).sorted(by: >))
        #expect(profile.sharedTournaments.allSatisfy { $0.status != .cancelled })
        let priya = try await repository.profile(userID: MockGroupFixtures.memberID(for: "Priya"))
        #expect(priya.bio == nil && priya.sharedTournaments.map(\.id) == ["mock-tournament-kickers-cup"],
                "Priya plays in Kickers Cup alone, with no fixture line about herself")
    }

    /// Priya is banned from Sunday Padel Crew and a member of Climbing Buddies, which the caller is not in.
    @Test func bannedRowsAndGroupsTheCallerIsNotInDoNotCount() async throws {
        let profile = try await repository.profile(userID: MockGroupFixtures.memberID(for: "Priya"))

        #expect(profile.displayName == "Priya" && profile.sharedGroups.isEmpty)
    }

    /// The caller's own profile: their groups by name, every joined game, every tournament they are in, and the bio the
    /// profile mock holds.
    @Test func theOwnProfileListsTheCallersGroupsGamesTournamentsAndBio() async throws {
        _ = try await profiles.updateBio("Football, mostly.")

        let profile = try await repository.profile(userID: TestFixtures.user.id)

        #expect(profile.displayName == "You" && profile.bio == "Football, mostly.")
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers", "Sunday Padel Crew", "Tempelhof Runners"])
        let joined = try await events.events(in: .joined, near: nil)
        #expect(Set(profile.sharedEvents.map(\.id)) == Set(joined.map(\.id)) && !joined.isEmpty)
        #expect(!profile.sharedTournaments.isEmpty)
    }

    @Test func unknownPeopleAreNotFoundAndGuestsAreRefused() async {
        await #expect(throws: AppError.userNotFound) { try await repository.profile(userID: "nobody") }
        await #expect(throws: AppError.userNotFound) { try await repository.startConversation(with: "nobody") }

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.profile(userID: marta) }
        await #expect(throws: AppError.sessionExpired) { try await repository.startConversation(with: marta) }
    }

    /// One conversation per pair: a direct group named after the person, the same one on every call, in Mine, its
    /// roster naming the person, and never a group in common.
    @Test func startConversationCreatesTheDirectGroupOnceAndAnswersItAgain() async throws {
        let conversation = try await repository.startConversation(with: jonas)

        #expect(conversation.id == MockGroupFixtures.directConversationID(for: jonas) && conversation.name == "Jonas")
        #expect(conversation.isDirect && conversation.counterpart == Counterpart(userId: jonas, displayName: "Jonas"))
        #expect(try await repository.startConversation(with: jonas) == conversation)
        #expect(try await groups.groups(in: .mine, cursor: nil, near: nil).items.contains(conversation))
        #expect(try await groups.members(id: conversation.id).map(\.displayName) == ["Jonas", "You"])
        #expect(try await repository.profile(userID: jonas).sharedGroups.map(\.name) == ["Kreuzberg Kickers"])
        #expect(logger.hasLine(in: .groups, at: .info, mentioning: conversation.id, "created", jonas))
    }

    /// The caller is nobody's counterpart.
    @Test func startingAConversationWithOneselfIsRefused() async {
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
