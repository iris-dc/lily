import Foundation
import Testing
@testable import lily

/// The terms wiring per launch argument; the main suite is past its type-body limit.
@MainActor
struct AppDependenciesTermsTests {
    /// `-mock-terms-pending` makes the mock account owe the terms; without it the mock has them accepted, and against
    /// a backend the flag means nothing.
    @Test func mockTermsPendingMakesTheMockOweTheTerms() {
        let pending = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents,
                                                              AppConfig.LaunchArguments.mockTermsPending],
                                                  defaults: makeTestDefaults())
        #expect((pending.meRepository as? MockMeRepository)?.owesTerms == true)

        let settled = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockEvents],
                                                  defaults: makeTestDefaults())
        #expect((settled.meRepository as? MockMeRepository)?.owesTerms == false)

        let remote = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.mockTermsPending],
                                                 defaults: makeTestDefaults())
        #expect(remote.meRepository is RemoteMeRepository, "the flag means nothing against a backend")
    }

    /// The chain without a backend: a guest is never asked, a sign-in under the flag loads an account owing the
    /// terms and the sheet is asked for, and the acceptance (the store's reload, the mock's PUT, the account replaced)
    /// takes it down again.
    @Test func thePendingMockRaisesTheTermsSheetAfterSignInUntilAccepted() async {
        let dependencies = AppDependencies.makeDefault(arguments: [AppConfig.LaunchArguments.resetSession,
                                                                   AppConfig.LaunchArguments.mockAuth,
                                                                   AppConfig.LaunchArguments.mockEvents,
                                                                   AppConfig.LaunchArguments.mockTermsPending],
                                                       defaults: makeTestDefaults())
        let terms = dependencies.makeTermsViewModel()
        #expect(!terms.isPresented, "a guest is never asked")

        await dependencies.sessionController.signIn(with: .apple)
        await dependencies.me.loadIfNeeded()
        #expect(terms.isPresented)

        await terms.accept()
        #expect(!terms.isPresented && !dependencies.me.needsTerms)
        #expect(dependencies.me.account?.termsAccepted == true)
    }
}
