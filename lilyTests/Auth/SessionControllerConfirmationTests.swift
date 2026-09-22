import Foundation
import Testing
@testable import lily

/// The email confirmation flow: sign-up and sign-in answering "confirmation required", confirming, resending.
@MainActor
struct SessionControllerConfirmationTests {
    /// A pool that emails a code answers "confirmation required": no sign-in yet, no popup, and the form takes over.
    @Test func signUpNeedingConfirmationNeitherSignsInNorReports() async {
        let harness = SessionHarness()
        harness.auth.signUpOutcome = .confirmationRequired

        let result = await harness.controller.signUp(email: "a@b.co", password: "long-enough")

        #expect(result == .confirmationRequired)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.controller.state == .loading)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("needs email confirmation") })
    }

    @Test func emailSignInRefusedAsUnconfirmedAsksForTheCodeWithoutAPopup() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.emailNotConfirmed)

        let result = await harness.controller.signIn(withEmail: TestFixtures.credentials)

        #expect(result == .confirmationRequired)
        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("needs email confirmation") })
    }

    @Test func emailSignInReportsSuccessAndFailure() async {
        let harness = SessionHarness()
        #expect(await harness.controller.signIn(withEmail: TestFixtures.credentials) == .signedIn)
        #expect(harness.controller.state == .signedIn(TestFixtures.user))

        harness.auth.signInResult = .failure(.invalidCredentials)
        #expect(await harness.controller.signIn(withEmail: TestFixtures.credentials) == .failed)
        #expect(harness.errorCenter.current?.error == .invalidCredentials)
    }

    @Test func confirmSignUpConfirmsThenSignsInWithTheKeptPassword() async {
        let harness = SessionHarness()
        let credentials = TestFixtures.credentials

        let signedIn = await harness.controller.confirmSignUp(email: credentials.email,
                                                              code: "123456",
                                                              password: credentials.password)

        #expect(signedIn)
        #expect(harness.auth.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.auth.signInProviders == [.email(credentials)])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Email confirmed") })
    }

    @Test func confirmSignUpFailureReportsAndDoesNotSignIn() async {
        let harness = SessionHarness()
        harness.auth.confirmError = .invalidConfirmationCode

        let signedIn = await harness.controller.confirmSignUp(email: "a@b.co", code: "000000", password: "long-enough")

        #expect(!signedIn)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.controller.state == .loading)
        #expect(harness.errorCenter.current?.error == .invalidConfirmationCode)
    }

    @Test func resendConfirmationCodeReportsFailuresAndLogsSuccess() async {
        let harness = SessionHarness()

        #expect(await harness.controller.resendConfirmationCode(email: "a@b.co"))
        #expect(harness.auth.resendEmails == ["a@b.co"])
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Confirmation code resent") })

        harness.auth.resendError = .tooManyAttempts
        #expect(await harness.controller.resendConfirmationCode(email: "a@b.co") == false)
        #expect(harness.errorCenter.current?.error == .tooManyAttempts)
    }
}
