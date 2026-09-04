import Testing
@testable import lily

@MainActor
struct EmailSignInViewModelTests {
    @Test func cannotSubmitUntilCredentialsAreValid() {
        let harness = SessionHarness()
        let viewModel = EmailSignInViewModel(session: harness.controller)

        #expect(!viewModel.canSubmit)
        viewModel.email = "jane@example.com"
        #expect(!viewModel.canSubmit)
        viewModel.password = "long-enough"
        #expect(viewModel.canSubmit)
    }

    @Test func signInModeSubmitsTrimmedEmail() async {
        let harness = SessionHarness()
        let viewModel = EmailSignInViewModel(session: harness.controller)
        viewModel.email = " jane@example.com "
        viewModel.password = "long-enough"

        let done = await viewModel.submit()

        #expect(done)
        #expect(harness.auth.signInProviders == [.email])
        #expect(!viewModel.isSubmitting)
    }

    @Test func signUpModeUsesSignUpPath() async {
        let harness = SessionHarness()
        let viewModel = EmailSignInViewModel(session: harness.controller)
        viewModel.toggleMode()
        viewModel.email = "jane@example.com"
        viewModel.password = "long-enough"

        let done = await viewModel.submit()

        #expect(viewModel.mode == .signUp)
        #expect(done)
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func submitFailureKeepsSheetOpen() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.invalidCredentials)
        let viewModel = EmailSignInViewModel(session: harness.controller)
        viewModel.email = "jane@example.com"
        viewModel.password = "long-enough"

        #expect(await viewModel.submit() == false)
        #expect(harness.errorCenter.current?.error == .invalidCredentials)
    }
}

@MainActor
struct WelcomeViewModelTests {
    @Test func providerActionsDelegateToSession() async {
        let harness = SessionHarness()
        let viewModel = WelcomeViewModel(session: harness.controller)

        await viewModel.signInWithApple()
        #expect(harness.auth.signInProviders == [.apple])

        viewModel.presentEmailSignIn()
        #expect(viewModel.isEmailSheetPresented)
    }

    @Test func guestPathEntersApp() {
        let harness = SessionHarness()
        WelcomeViewModel(session: harness.controller).continueAsGuest()
        #expect(harness.controller.state == .guest)
    }
}
