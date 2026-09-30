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
    /// conversation started here is in Mine on the next load.
    @Test func theMockProfilesFollowTheMockRostersAndConversationsReachMine() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        let marta = UserProfileDestination(userId: MockGroupFixtures.memberID(for: "Marta"), displayName: "Marta")
        let viewModel = dependencies.makeUserProfileViewModel(for: marta)

        await viewModel.load()
        #expect(viewModel.profile?.sharedGroups.map(\.name) == ["Kreuzberg Kickers"])
        #expect(viewModel.canMessage && !viewModel.isSelf)

        await viewModel.message()
        let conversation = try #require(dependencies.myGroups.groups.first { $0.isDirect })
        #expect(conversation.name == "Marta" && dependencies.navigation.selectedTab == .chat)
        await dependencies.myGroups.reload()
        #expect(dependencies.myGroups.groups.contains(conversation), "the group mock remembers the conversation")
        #expect(!dependencies.myGroups.communities.contains(conversation), "Home never lists a conversation")
    }
}
