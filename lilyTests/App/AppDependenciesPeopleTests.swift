import Foundation
import Testing
@testable import lily

/// The people wiring per launch argument; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesPeopleTests {
    @Test func mockEventsSelectTheMockUserRepositoryAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.userRepository is MockUserRepository)
        #expect(AppDependencies.makeMock().userRepository is MockUserRepository)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.userRepository is RemoteUserRepository)
    }

    /// The user mock reads the group mock's rosters, so a profile names the people the other mocks name and a
    /// conversation started here is in Mine on the next load; the shared history comes from the event and tournament
    /// mocks (Marta hosts Sunset 5-a-side, which the caller joined, and organises the table tennis the caller plays).
    @Test func theMockProfilesFollowTheMockRostersAndConversationsReachMine() async throws {
        let dependencies = await makeSignedInMockDependencies()
        let marta = UserProfileDestination(userId: MockGroupFixtures.memberID(for: "Marta"), displayName: "Marta")
        let viewModel = dependencies.makeUserProfileViewModel(for: marta)

        await viewModel.load()
        let profile = try #require(viewModel.profile)
        #expect(profile.sharedGroups.map(\.name) == ["Kreuzberg Kickers"])
        #expect(profile.bio == MockUserFixtures.bio(of: marta.userId) && profile.bio?.isEmpty == false)
        #expect(profile.sharedEvents.map(\.title).contains("Sunset 5-a-side"))
        #expect(profile.sharedEvents.map(\.startsAt) == profile.sharedEvents.map(\.startsAt).sorted(by: >), "latest first")
        #expect(profile.sharedTournaments.map(\.id).contains("mock-tournament-table-tennis"))
        #expect(profile.sharedTournaments.allSatisfy { $0.status != .cancelled })
        #expect(viewModel.canMessage && !viewModel.isSelf)

        await viewModel.message()
        let conversation = try #require(dependencies.myGroups.groups.first { $0.isDirect })
        #expect(conversation.name == "Marta" && dependencies.navigation.selectedTab == .chat)
        await dependencies.myGroups.reload()
        #expect(dependencies.myGroups.groups.contains(conversation), "the group mock remembers the conversation")
        #expect(!dependencies.myGroups.communities.contains(conversation), "Home never lists a conversation")
    }

    /// The caller's own profile lists their own rooms and games and carries the bio the profile mock holds.
    @Test func theMockOwnProfileCarriesTheWrittenBioAndOwnHistory() async throws {
        let dependencies = await makeSignedInMockDependencies()
        _ = try await dependencies.profile.updateBio(to: "Football, mostly.")
        let me = UserProfileDestination(userId: try #require(dependencies.identity.currentUserID), displayName: "You")
        let viewModel = dependencies.makeUserProfileViewModel(for: me)

        await viewModel.load()

        let profile = try #require(viewModel.profile)
        #expect(viewModel.isSelf && profile.bio == "Football, mostly.")
        #expect(!profile.sharedEvents.isEmpty && !profile.sharedTournaments.isEmpty && !profile.sharedGroups.isEmpty)
    }
}
