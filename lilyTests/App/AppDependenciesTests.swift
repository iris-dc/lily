import Foundation
import Testing
@testable import lily

@MainActor
struct AppDependenciesTests {
    @Test func resetSessionLaunchArgumentClearsStoredSession() {
        let defaults = makeTestDefaults()
        let store = UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger())
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession], defaults: defaults)

        #expect(store.load() == nil)
    }

    @Test func defaultLaunchKeepsStoredSession() {
        let defaults = makeTestDefaults()
        let store = UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger())
        store.save(.guest)

        _ = AppDependencies.makeDefault(arguments: [], defaults: defaults)

        #expect(store.load() == .guest)
    }

    @Test func startAsGuestLaunchArgumentStoresGuestChoice() {
        let defaults = makeTestDefaults()
        _ = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                    AppConfig.LaunchArguments.startAsGuest],
                                        defaults: defaults)
        #expect(UserDefaultsSessionStore(defaults: defaults, logger: SpyLogger()).load() == .guest)
    }

    @Test func mockAuthFailLaunchArgumentMakesSignInFailWithAPopup() async {
        let failing = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                              AppConfig.LaunchArguments.mockAuthFail],
                                                  defaults: makeTestDefaults())
        let signedIn = await failing.sessionController.signIn(with: .apple)
        #expect(!signedIn)
        #expect(failing.errorCenter.current != nil)
        #expect(failing.sessionController.state.user == nil)
    }

    /// The shell binds to one navigation object and the events code to one tracker; a second instance would split them.
    @Test func groupCollaboratorsAreSharedInstances() {
        let dependencies = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())

        #expect(dependencies.navigation === dependencies.groups.navigation)
        #expect(dependencies.groupChanges === dependencies.groups.groupChanges)
        #expect(dependencies.groupChanges !== dependencies.eventChanges)
        #expect(dependencies.myGroups === dependencies.groups.myGroups)
        #expect(dependencies.me === dependencies.groups.me)
    }

    /// The factories wire the mocks together: the mock code previews the private climbing group for a guest.
    @Test func theMockInviteCodePreviewsClimbingBuddiesThroughTheFactories() async {
        let dependencies = AppDependencies.makeMock()
        let viewModel = dependencies.makeJoinWithCodeViewModel { _ in }

        viewModel.input = AppConfig.Groups.mockInviteCode
        await viewModel.proceed()

        #expect(viewModel.preview?.groupName == "Climbing Buddies")
        #expect(viewModel.preview?.needsSignIn == true)
    }

    /// Everything talks to the same backend, or everything stays in memory: a mock run never reaches Laurel for groups.
    @Test func mockEventsSelectTheMockGroupRepositoriesAndTheDefaultTheRemoteOnes() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.groupRepository is MockGroupRepository)
        #expect(mocked.inviteRepository is MockInviteRepository)
        #expect(mocked.meRepository is MockMeRepository)
        #expect(mocked.moderationRepository is MockModerationRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.groupRepository is RemoteGroupRepository)
        #expect(remote.inviteRepository is RemoteInviteRepository)
        #expect(remote.meRepository is RemoteMeRepository)
        #expect(remote.moderationRepository is RemoteModerationRepository)
        #expect(AppDependencies.makeMock().groupRepository is MockGroupRepository)
    }

    /// The stores hold a user's data for the app's lifetime, so a sign-out must reach them.
    @Test func groupStoresClearOnSignOut() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.myGroups.reload()
        await dependencies.me.loadIfNeeded()
        #expect(dependencies.myGroups.groups.count == 3 && dependencies.me.isOperator)

        await dependencies.sessionController.signOut()

        #expect(dependencies.myGroups.groups.isEmpty && dependencies.me.account == nil)
    }

    /// Two simulators can act as two people: the flag replaces the id of every mock sign-in and names the user after it.
    @Test func mockUserIDLaunchArgumentOverridesEveryMockSignIn() async {
        let arguments = [AppConfig.LaunchArguments.resetSession, AppConfig.LaunchArguments.mockAuth,
                         AppConfig.LaunchArguments.mockEvents, AppConfig.LaunchArguments.mockUserID, "jane.doe"]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())

        await dependencies.sessionController.signIn(with: .apple)
        let expected = AuthUser(id: "jane.doe", displayName: "Jane Doe", email: "jane.doe@example.com")
        #expect(dependencies.sessionController.state.user == expected)
        await dependencies.sessionController.signOut()

        _ = await dependencies.sessionController.signIn(withEmail: TestFixtures.credentials)
        #expect(dependencies.identity.currentUserID == "jane.doe")
    }

    /// Without the flag the defaults stay, as `LilySignInTests` asserts on "Apple Tester".
    @Test func mockSignInsKeepTheirDefaultUsersWithoutTheFlag() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        await dependencies.sessionController.signIn(with: .apple)
        #expect(dependencies.sessionController.state.user == MockUsers.user(for: .apple))
    }

    @Test func openInviteLaunchArgumentSeedsTheSharedDeepLinkCenter() {
        let arguments = [AppConfig.LaunchArguments.openInvite, AppConfig.Groups.mockInviteCode]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())

        #expect(dependencies.deepLinks === dependencies.groups.deepLinks)
        #expect(dependencies.deepLinks.pendingInvite?.value == AppConfig.Groups.mockInviteCode)
        #expect(AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults()).deepLinks.pendingInvite == nil)
    }

    /// Nothing here touches Amplify: the client configures it on its first call, and none is made.
    @Test func defaultAuthIsCognitoAndFeedsTheTokenProvider() {
        let dependencies = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())

        #expect(dependencies.authService is CognitoAuthService)
        #expect(dependencies.tokenProvider is CognitoAuthService)
    }

    @Test func mockAuthLaunchArgumentSelectsTheMockWithoutATokenProvider() {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockAuth],
                                                       defaults: makeTestDefaults())

        #expect(dependencies.authService is MockAuthService)
        #expect(dependencies.tokenProvider == nil)
    }

    @Test func mockAuthConfirmLaunchArgumentAsksForTheMockCode() async {
        let arguments = [AppConfig.LaunchArguments.resetSession, AppConfig.LaunchArguments.mockAuth,
                         AppConfig.LaunchArguments.mockAuthConfirm, AppConfig.LaunchArguments.mockEvents]
        let dependencies = AppDependencies.makeDefault(arguments: arguments, defaults: makeTestDefaults())
        let controller = dependencies.sessionController

        #expect(await controller.signUp(email: "a@b.co", password: "long-enough") == .confirmationRequired)
        #expect(await controller.confirmSignUp(email: "a@b.co", code: "000000", password: "long-enough") == false)
        #expect(dependencies.errorCenter.current?.error == .invalidConfirmationCode)
        let code = AppConfig.Auth.mockConfirmationCode
        #expect(await controller.confirmSignUp(email: "a@b.co", code: code, password: "long-enough"))
        #expect(controller.state.user != nil)
    }

    /// Fail beats confirm beats plain, so a test can add a flag to the default `-mock-auth` launch.
    @Test func mockAuthBehaviorFollowsTheLaunchArguments() {
        let flags = AppConfig.LaunchArguments.self
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockEvents]) == nil)
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuth]) == .succeed)
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuth, flags.mockAuthConfirm])
                == .requireConfirmation(code: AppConfig.Auth.mockConfirmationCode))
        #expect(AppDependencies.mockAuthBehavior(from: [flags.mockAuthConfirm, flags.mockAuthFail]) == .fail(.network))
    }

    @Test func mockLocationLaunchArgumentSelectsMockService() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockLocation],
                                                 defaults: makeTestDefaults())
        #expect(mocked.locationService is MockLocationService)
        let real = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect((real.locationService as? CachedLocationService)?.upstream is CoreLocationService)
    }

    @Test func mockEventsLaunchArgumentSelectsInMemoryRepositories() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.eventRepository is MockEventRepository)
        #expect(mocked.profileRepository is MockProfileRepository)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.eventRepository is RemoteEventRepository)
        #expect(remote.profileRepository is RemoteProfileRepository)
    }

    /// A mock run (UI tests, previews, `-mock-events`) must never post a statistic; the default wiring posts to the
    /// same backend the repositories use.
    @Test func mockEventsSelectTheNoOpRecorderAndTheDefaultTheRemoteOne() {
        let mocked = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents], defaults: makeTestDefaults())
        #expect(mocked.interactionRecorder is NoOpInteractionRecorder)
        #expect(AppDependencies.makeMock().interactionRecorder is NoOpInteractionRecorder)
        let remote = AppDependencies.makeDefault(arguments: [], defaults: makeTestDefaults())
        #expect(remote.interactionRecorder is RemoteInteractionRecorder)
    }

    @Test func apiBaseURLLaunchArgumentOverridesTheDefault() {
        let logger = SpyLogger()
        let arguments = [AppConfig.LaunchArguments.apiBaseURL, "http://mac.local:8080", AppConfig.LaunchArguments.mockLocation]

        let url = AppDependencies.apiBaseURL(from: arguments, logger: logger)

        #expect(url == URL(string: "http://mac.local:8080"))
        #expect(logger.messages(in: .network, at: .info) == ["API base URL overridden: http://mac.local:8080"])
    }

    @Test func apiBaseURLLaunchArgumentWithoutSchemeOrHostIsIgnoredWithAWarning() {
        let logger = SpyLogger()

        let url = AppDependencies.apiBaseURL(from: [AppConfig.LaunchArguments.apiBaseURL, "mac.local:8080"], logger: logger)

        #expect(url == AppConfig.API.baseURL)
        #expect(logger.messages(in: .network, at: .warning).count == 1)
        #expect(logger.messages(in: .network, at: .info).isEmpty)
    }

    @Test func apiBaseURLIsTheConfiguredOneWithoutTheArgument() {
        let logger = SpyLogger()

        let url = AppDependencies.apiBaseURL(from: [AppConfig.LaunchArguments.mockLocation], logger: logger)

        #expect(url == AppConfig.API.baseURL)
        #expect(logger.entries.isEmpty)
    }

    @Test func makeMockNeverTouchesTheNetwork() {
        let mock = AppDependencies.makeMock()
        #expect(mock.eventRepository is MockEventRepository)
        #expect(mock.profileRepository is MockProfileRepository)
    }

    /// The API client and the event screens ask `identity`; it must follow the session without extra wiring.
    @Test func identityFollowsTheSession() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents],
                                                       defaults: makeTestDefaults())
        #expect(dependencies.identity.currentUserID == nil)

        await dependencies.sessionController.signIn(with: .apple)
        #expect(dependencies.identity.currentUserID == MockUsers.user(for: .apple).id)

        await dependencies.sessionController.signOut()
        #expect(dependencies.identity.currentUserID == nil)
    }

    /// Lists without a filter button (My Events, a group's games) must never hide a game, however far away; Explore
    /// starts from the default filter.
    @Test func myEventsAndGroupListsStartFromEverythingAndExploreFromTheDefaults() {
        let dependencies = AppDependencies.makeMock()
        #expect(dependencies.makeEventListViewModel(scope: .joined).filter == .everything)
        #expect(dependencies.makeEventListViewModel(scope: .group(id: MockGroupFixtures.kickersID)).filter == .everything)
        #expect(dependencies.makeEventListViewModel(scope: .upcoming).filter == EventFilter())
    }
}
