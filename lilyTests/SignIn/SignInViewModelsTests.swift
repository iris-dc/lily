import Testing
@testable import lily

@MainActor
struct EmailSignInViewModelTests {
    private let credentials = EmailCredentials(email: "jane@example.com", password: "long-enough")

    private func makeViewModel(_ harness: SessionHarness) -> EmailSignInViewModel {
        let viewModel = EmailSignInViewModel(session: harness.controller)
        viewModel.email = credentials.email
        viewModel.password = credentials.password
        return viewModel
    }

    @Test func copyComesFromBrandingSoSheetAndFormCannotDrift() {
        #expect(EmailAuthMode.signIn.title == AppBranding.signInSheetTitle)
        #expect(EmailAuthMode.signIn.submitLabel == AppBranding.signInAction)
        #expect(EmailAuthMode.signUp.toggleLabel == "\(AppBranding.signInPrompt) \(AppBranding.signInAction)")
    }

    @Test func cannotSubmitUntilCredentialsAreValid() {
        let harness = SessionHarness()
        let viewModel = EmailSignInViewModel(session: harness.controller)

        #expect(!viewModel.canSubmit)
        viewModel.email = credentials.email
        #expect(!viewModel.canSubmit)
        viewModel.password = credentials.password
        #expect(viewModel.canSubmit)
    }

    @Test func signInModeSubmitsTrimmedEmail() async {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.email = " \(credentials.email) "

        viewModel.submit()
        #expect(viewModel.isSubmitting)
        await viewModel.submitTask?.value

        #expect(harness.auth.signInProviders == [.email(credentials)])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(!viewModel.isSubmitting)
    }

    @Test func signUpModeUsesSignUpPath() async {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.toggleMode()

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.mode == .signUp)
        #expect(harness.auth.signUpRequests == [credentials])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
    }

    @Test func submitFailureKeepsFormOpen() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.invalidCredentials)
        let viewModel = makeViewModel(harness)

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current?.error == .invalidCredentials)
        #expect(!viewModel.isSubmitting)
    }

    /// The keyboard's return key reaches `submit()` even while the button is disabled.
    @Test func submitWithInvalidFormIsIgnored() async {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.password = "short"

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.submitTask == nil)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.errorCenter.current == nil)
        #expect(!viewModel.isSubmitting)
    }

    @Test func cancelStopsInFlightSignInWithoutAnError() async {
        let harness = SessionHarness()
        harness.auth.delay = .milliseconds(200)
        let viewModel = makeViewModel(harness)

        viewModel.submit()
        let task = viewModel.submitTask
        viewModel.cancel()
        await task?.value

        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current == nil)
        #expect(!viewModel.isSubmitting)
        #expect(viewModel.submitTask == nil)
    }

    @Test func cancelStopsInFlightSignUpWithoutAnError() async {
        let harness = SessionHarness()
        harness.auth.delay = .milliseconds(200)
        let viewModel = makeViewModel(harness)
        viewModel.toggleMode()

        viewModel.submit()
        let task = viewModel.submitTask
        viewModel.cancel()
        await task?.value

        #expect(harness.controller.state == .loading)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("cancelled") })
    }
}

@MainActor
struct SignInViewModelTests {
    @Test func providerActionsDelegateToSession() async {
        let harness = SessionHarness()
        let viewModel = SignInViewModel(session: harness.controller)

        viewModel.signInWithApple()
        await viewModel.signInTask?.value
        #expect(harness.auth.signInProviders == [.apple])

        viewModel.signInWithGoogle()
        await viewModel.signInTask?.value
        #expect(harness.auth.signInProviders == [.apple, .google])

        viewModel.presentEmailForm()
        #expect(viewModel.isEmailFormPresented)
    }

    /// Dismissing the sheet mid sign-in must neither sign the user in later nor show an error popup.
    @Test func cancelStopsInFlightSignInQuietly() async {
        let harness = SessionHarness()
        harness.auth.delay = .milliseconds(200)
        let viewModel = SignInViewModel(session: harness.controller)

        viewModel.signInWithApple()
        let task = viewModel.signInTask
        viewModel.cancel()
        await task?.value

        #expect(harness.controller.state == .loading)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.errorCenter.current == nil)
        #expect(viewModel.signInTask == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("cancelled") })
    }
}
