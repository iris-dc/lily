import Foundation
@testable import lily

/// Scripted pool: every answer is a field, every call is recorded. A `.done` sign-in flips `signedIn` like the real one.
@MainActor
final class FakeCognitoClient: CognitoClient {
    var signedIn = false
    var tokenResult: Result<String?, CognitoClientError> = .success("access-token")
    var freshTokenResult: Result<String?, CognitoClientError> = .success("fresh-access-token")
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
    private(set) var freshTokenRequestCount = 0

    func isSignedIn() async throws -> Bool { signedIn }

    func accessToken() async throws -> String? { try tokenResult.get() }

    func freshAccessToken() async throws -> String? {
        freshTokenRequestCount += 1
        return try freshTokenResult.get()
    }

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

/// Answers a fixed token, or none, so the API client's header can be checked. Fresh tokens come from a script, one
/// per request, and fall back to `token` once the script is used up, so a reconnect can be handed a chosen `exp`.
@MainActor
final class FakeAuthTokenProvider: AuthTokenProvider {
    var token: String?
    var freshTokens: [String?] = []
    private(set) var requestCount = 0
    private(set) var freshRequestCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    func accessToken() async -> String? {
        requestCount += 1
        return token
    }

    func freshAccessToken() async -> String? {
        freshRequestCount += 1
        guard !freshTokens.isEmpty else { return token }
        return freshTokens.removeFirst()
    }
}

/// Unsigned JWTs with a chosen expiry, for everything that reads `exp` off a token.
enum JWTFixtures {
    static func token(expiringAt date: Date, subject: String = TestFixtures.user.id) -> String {
        let payload = #"{"sub":"\#(subject)","exp":\#(Int(date.timeIntervalSince1970))}"#
        return "\(base64url(#"{"alg":"none"}"#)).\(base64url(payload)).signature"
    }

    private static func base64url(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Counts `sessionDidEnd()` calls; `onSessionEnd` lets a test look at the controller at that moment.
@MainActor
final class SpySessionObserver: SessionObserver {
    private(set) var endCount = 0
    var onSessionEnd: () -> Void = {}

    func sessionDidEnd() {
        endCount += 1
        onSessionEnd()
    }
}
