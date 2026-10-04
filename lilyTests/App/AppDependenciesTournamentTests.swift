import Foundation
import Testing
@testable import lily

/// The tournament wiring per launch argument; the main suite is at its type-body limit.
@MainActor
struct AppDependenciesTournamentTests {
    @Test func mockEventsSelectTheMockRepositoryAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.tournamentRepository is MockTournamentRepository)
        #expect(mocked.tournamentInviteRepository is MockTournamentInviteRepository)
        #expect(AppDependencies.makeMock().tournamentRepository is MockTournamentRepository)

        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.tournamentRepository is RemoteTournamentRepository)
        #expect(remote.tournamentInviteRepository is RemoteTournamentInviteRepository)
    }

    /// One change counter for the lists, the realtime controller and the inbox; the invite and report sheets open on
    /// the tournament's id.
    @Test func theTournamentCollaboratorsShareOneChangeCounter() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.tournamentChanges === dependencies.realtime.tournamentChanges)
        #expect(dependencies.makeTournamentInvitePeopleViewModel(for: "t1").target == .tournament(id: "t1"))
        let report = dependencies.makeReportViewModel(for: .tournament(id: "t1"), title: AppBranding.Tournaments.report)
        #expect(report.target == .tournament(id: "t1") && report.title == "Report tournament")
    }

    /// The factories hand every view model the shared repository and change counter, and the mock's two tournaments
    /// reach Home's list for a signed-in caller while their rooms stay out of the communities.
    @Test func theFactoriesAndTheMockFixturesWorkTogether() async throws {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        let mine = dependencies.makeTournamentListViewModel(scope: .mine)
        await mine.load()
        #expect(mine.tournaments.map(\.name) == ["Tuesday Table Tennis", "Kickers Cup"])

        let detail = dependencies.makeTournamentDetailViewModel(for: mine.tournaments[1].destination) { _ in }
        await detail.load()
        #expect(detail.role == .organizer && detail.participation == .createTeam)

        await dependencies.myGroups.reload()
        #expect(dependencies.myGroups.groups.contains { $0.isTournamentRoom })
        #expect(!dependencies.myGroups.communities.contains { $0.isTournamentRoom })
        #expect(dependencies.myGroups.communities.count == 3, "the caller's three fixture communities")

        let create = dependencies.makeCreateTournamentViewModel { _ in }
        #expect(create.draft.group == nil && create.lockedGroup == nil)
        #expect(dependencies.makeEditTournamentViewModel(for: mine.tournaments[1]) { _ in }.isLocked == false)
    }
}
