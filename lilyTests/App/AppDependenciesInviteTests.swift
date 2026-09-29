import Foundation
import Testing
@testable import lily

/// The invite wiring per launch argument and the mock invite flow end to end; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesInviteTests {
    @Test func mockEventsSelectTheMockInviteRepositoryAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.inviteRepository is MockInviteRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.inviteRepository is RemoteInviteRepository)
        #expect(AppDependencies.makeMock().inviteRepository is MockInviteRepository)
    }

    /// The mock run end to end: the owner of Sunday Padel Crew sees Marta from Kreuzberg Kickers and invites her.
    @Test func theMockInviteFlowWorksThroughTheFactory() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.myGroups.reload()
        let padel = try #require(dependencies.myGroups.groups.first { $0.id == MockGroupFixtures.padelID })
        let viewModel = dependencies.makeInvitePeopleViewModel(for: padel)

        await viewModel.load()
        let marta = try #require(viewModel.candidates.first { $0.userId == MockGroupFixtures.memberID(for: "Marta") })
        #expect(viewModel.content == .people && marta.caption == "In Kreuzberg Kickers")

        await viewModel.invite(marta)
        #expect(viewModel.candidates.first { $0.userId == marta.userId }?.isInvited == true)
        #expect(dependencies.errorCenter.current == nil)
    }
}
