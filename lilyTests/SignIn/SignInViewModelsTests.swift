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
        #expect(EmailAuthMode.confirm.title == AppBranding.confirmEmailTitle)
        #expect(EmailAuthMode.confirm.submitLabel == AppBranding.confirmAction)
        #expect(EmailAuthMode.confirm.toggleLabel == AppBranding.backToSignInAction)
        #expect(EmailAuthMode.confirm.toggled == .signIn)
    }

    @Test func confirmStepNamesTheEmailInTheSubtitle() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        #expect(viewModel.subtitle == AppBranding.emailSignInSubtitle)

        viewModel.mode = .confirm
        #expect(viewModel.subtitle == "We sent a code to \(credentials.email)")
    }

    @Test func confirmStepSubmitsOnlyACompleteNumericCode() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm

        #expect(!viewModel.canSubmit)
        viewModel.code = "12345"
        #expect(!viewModel.canSubmit)
        viewModel.code = "12345a"
        #expect(!viewModel.canSubmit)
        viewModel.code = "123456"
        #expect(viewModel.canSubmit)
    }

    @Test func signUpNeedingConfirmationSwitchesToTheConfirmStep() async {
        let harness = SessionHarness()
        harness.auth.signUpOutcome = .confirmationRequired
        let viewModel = makeViewModel(harness)
        viewModel.toggleMode()

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.mode == .confirm)
        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current == nil)
    }

    @Test func signInRefusedAsUnconfirmedSwitchesToTheConfirmStep() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.emailNotConfirmed)
        let viewModel = makeViewModel(harness)

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.mode == .confirm)
        #expect(harness.errorCenter.current == nil)
    }

    @Test func confirmSubmitsTheCodeAndSignsInWithTheKeptPassword() async {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm
        viewModel.code = "123456"

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(harness.auth.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.auth.signInProviders == [.email(credentials)])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(!viewModel.isSubmitting)
    }

    @Test func resendCodeAsksForANewOneOnlyOnTheConfirmStep() async {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)

        viewModel.resendCode()
        #expect(viewModel.submitTask == nil)

        viewModel.mode = .confirm
        viewModel.resendCode()
        #expect(viewModel.isResending)
        await viewModel.submitTask?.value

        #expect(harness.auth.resendEmails == [credentials.email])
        #expect(!viewModel.isResending)
    }

    @Test func backToSignInDropsTheCode() {
        let harness = SessionHarness()
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm
        viewModel.code = "123456"

        viewModel.toggleMode()

        #expect(viewModel.mode == .signIn)
        #expect(viewModel.code.isEmpty)
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
