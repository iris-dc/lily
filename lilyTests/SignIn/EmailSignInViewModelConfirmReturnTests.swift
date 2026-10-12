import Testing
@testable import lily

/// The code step after the pool accepted the code: a second Confirm would be refused, so the form returns to sign-in.
extension EmailSignInViewModelTests {
    @Test func aConfirmedAccountWhoseSignInFailedReturnsToSignIn() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.network)
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm
        viewModel.code = "123456"

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.mode == .signIn)
        #expect(viewModel.code.isEmpty)
        #expect(viewModel.email == credentials.email)
        #expect(viewModel.password == credentials.password)
        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.controller.state == .loading)
        #expect(!viewModel.isSubmitting)
    }

    @Test func aSecondConfirmIsNeverSentForAConfirmedAccount() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.network)
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm
        viewModel.code = "123456"
        viewModel.submit()
        await viewModel.submitTask?.value

        harness.auth.signInResult = .success(TestFixtures.session)
        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(harness.auth.confirmations.count == 1)
        #expect(harness.auth.signInProviders == [.email(credentials), .email(credentials)])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(viewModel.mode == .signIn)
    }

    @Test func aRefusedCodeKeepsTheConfirmStepAndItsCode() async {
        let harness = SessionHarness()
        harness.auth.confirmError = .invalidConfirmationCode
        let viewModel = makeViewModel(harness)
        viewModel.mode = .confirm
        viewModel.code = "000000"

        viewModel.submit()
        await viewModel.submitTask?.value

        #expect(viewModel.mode == .confirm)
        #expect(viewModel.code == "000000")
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.errorCenter.current?.error == .invalidConfirmationCode)
    }
}
