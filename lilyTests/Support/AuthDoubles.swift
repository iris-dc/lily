import Foundation
@testable import lily

/// Scripted pool: every answer is a field, every call is recorded. A `.done` sign-in flips `signedIn` like the real one.
@MainActor
final class FakeCognitoClient: CognitoClient {
    var signedIn = false
    var tokenResult: Result<String?, CognitoClientError> = .success("access-token")
    var user = CognitoUser(sub: "sub-1", username: "5c4d-uuid")
    var emailResult: Result<String?, CognitoClientError> = .success(TestFixtures.credentials.email)
    var signInResult: Result<CognitoSignInStep, CognitoClientError> = .success(.done)
    var signUpResult: Result<CognitoSignUpStep, CognitoClientError> = .success(.confirmationRequired)
    var confirmError: CognitoClientError?
    var resendError: CognitoClientError?
    var signOutError: CognitoClientError?
    private(set) var signIns: [EmailCredentials] = []
    private(set) var signUps: [EmailCredentials] = []
    private(set) var confirmations: [FakeAuthService.ConfirmationRequest] = []
    private(set) var resendEmails: [String] = []
    private(set) var signOutCount = 0

    func isSignedIn() async throws -> Bool { signedIn }

    func accessToken() async throws -> String? { try tokenResult.get() }

    func currentUser() async throws -> CognitoUser { user }

    func fetchEmail() async throws -> String? { try emailResult.get() }

    func signIn(username: String, password: String) async throws -> CognitoSignInStep {
        signIns.append(EmailCredentials(email: username, password: password))
        let step = try signInResult.get()
        if step == .done { signedIn = true }
        return step
    }

    func signUp(email: String, password: String) async throws -> CognitoSignUpStep {
        signUps.append(EmailCredentials(email: email, password: password))
        return try signUpResult.get()
    }

    func confirmSignUp(email: String, code: String) async throws {
        confirmations.append(FakeAuthService.ConfirmationRequest(email: email, code: code))
        if let confirmError { throw confirmError }
    }

    func resendCode(email: String) async throws {
        resendEmails.append(email)
        if let resendError { throw resendError }
    }

    func signOut() async throws {
        signOutCount += 1
        signedIn = false
        if let signOutError { throw signOutError }
    }
}

/// Answers a fixed token, or none, so the API client's header can be checked.
@MainActor
final class FakeAuthTokenProvider: AuthTokenProvider {
    var token: String?
    private(set) var requestCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func accessToken() async -> String? {
        requestCount += 1
        return token
    }
}
