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
        #expect(harness.controller.state == .signedOut)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("needs email confirmation") })
    }

    @Test func emailSignInRefusedAsUnconfirmedAsksForTheCodeWithoutAPopup() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.emailNotConfirmed)

        let result = await harness.controller.signIn(withEmail: TestFixtures.credentials)

        #expect(result == .confirmationRequired)
        #expect(harness.controller.state == .signedOut)
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

    /// The sign-in after an accepted sign-up reports its own failure once: one popup and one error line, both the sign-in's.
    @Test func aSignInFailureAfterSignUpIsReportedOnce() async {
        let harness = SessionHarness()
        let credentials = TestFixtures.credentials
        harness.auth.signUpOutcome = .signedUp
        harness.auth.signInResult = .failure(.network)

        let result = await harness.controller.signUp(email: credentials.email, password: credentials.password)

        #expect(result == .failed)
        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.logger.messages(in: .auth, at: .error).count == 1, "the sign-in's line alone")
        #expect(harness.controller.state == .signedOut)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.auth.signInProviders == [.email(credentials)])
    }

    @Test func confirmSignUpConfirmsThenSignsInWithTheKeptPassword() async {
        let harness = SessionHarness()
        let credentials = TestFixtures.credentials

        let outcome = await harness.controller.confirmSignUp(email: credentials.email,
                                                             code: "123456",
                                                             password: credentials.password)

        #expect(outcome == .signedIn)
        #expect(harness.auth.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.auth.signInProviders == [.email(credentials)])
        #expect(harness.controller.state == .signedIn(TestFixtures.user))
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.logger.messages(in: .auth).contains { $0.contains("Email confirmed") })
    }

    /// The pool accepted the code, so a second confirm would be refused as "not authorized": the answer sends the form
    /// back to sign-in, and the failed sign-in has already shown its own popup.
    @Test func confirmSucceedsButTheSignInAfterItAnswersConfirmedButSignInFailed() async {
        let harness = SessionHarness()
        let credentials = TestFixtures.credentials
        harness.auth.signInResult = .failure(.network)

        let outcome = await harness.controller.confirmSignUp(email: credentials.email,
                                                             code: "123456",
                                                             password: credentials.password)

        #expect(outcome == .confirmedButSignInFailed)
        #expect(harness.auth.confirmations == [FakeAuthService.ConfirmationRequest(email: credentials.email, code: "123456")])
        #expect(harness.auth.signInProviders == [.email(credentials)])
        #expect(harness.errorCenter.current?.error == .network)
        #expect(harness.controller.state == .signedOut)
        #expect(harness.controller.authenticatingProvider == nil)
        #expect(harness.logger.messages(in: .auth, at: .info).contains { $0.contains("returns to sign-in") })
    }

    /// A sign-in still asking for the code right after a confirm did not land either: the form returns to sign-in,
    /// and a sign-in made there enters the code step on its own. No popup, as for any "confirmation required".
    @Test func aSignInStillAskingForTheCodeAfterAConfirmAnswersConfirmedButSignInFailed() async {
        let harness = SessionHarness()
        harness.auth.signInResult = .failure(.emailNotConfirmed)

        let outcome = await harness.controller.confirmSignUp(email: "a@b.co", code: "123456", password: "long-enough")

        #expect(outcome == .confirmedButSignInFailed)
        #expect(harness.errorCenter.current == nil)
        #expect(harness.controller.state == .signedOut)
    }

    /// A refused code is `.failed`, never `.confirmedButSignInFailed`: the form keeps the code step, no sign-in is tried.
    @Test func confirmSignUpFailureReportsAndDoesNotSignIn() async {
        let harness = SessionHarness()
        harness.auth.confirmError = .invalidConfirmationCode

        let outcome = await harness.controller.confirmSignUp(email: "a@b.co", code: "000000", password: "long-enough")

        #expect(outcome == .failed)
        #expect(harness.auth.signInProviders.isEmpty)
        #expect(harness.controller.state == .signedOut)
        #expect(harness.controller.authenticatingProvider == nil)
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
