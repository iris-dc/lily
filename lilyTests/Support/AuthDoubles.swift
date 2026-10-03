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
    private(set) var languageCodes: [String] = []
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

    func signUp(email: String, password: String, languageCode: String) async throws -> CognitoSignUpStep {
        signUps.append(EmailCredentials(email: email, password: password))
        languageCodes.append(languageCode)
        return try signUpResult.get()
    }

    func confirmSignUp(email: String, code: String) async throws {
        confirmations.append(FakeAuthService.ConfirmationRequest(email: email, code: code))
        if let confirmError { throw confirmError }
    }

    func resendCode(email: String, languageCode: String) async throws {
        resendEmails.append(email)
        languageCodes.append(languageCode)
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
/// `holdsRequests` parks every request until `releaseRequests()`, so a test can act while a token is being fetched.
@MainActor
final class FakeAuthTokenProvider: AuthTokenProvider {
    var token: String?
    var freshTokens: [String?] = []
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    private let hold = RequestHold()
    private(set) var requestCount = 0
    private(set) var freshRequestCount = 0

    init(token: String? = nil) {
        self.token = token
    }

    /// A request held right now.
    var isHolding: Bool { hold.isHolding }

    func accessToken() async -> String? {
        requestCount += 1
        await hold.wait()
        return token
    }

    func freshAccessToken() async -> String? {
        freshRequestCount += 1
        await hold.wait()
        guard !freshTokens.isEmpty else { return token }
        return freshTokens.removeFirst()
    }

    func releaseRequests() {
        hold.release()
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

/// Counts `sessionWillEnd()` and `sessionDidEnd()` calls; the closures let a test look at the controller at that moment.
@MainActor
final class SpySessionObserver: SessionObserver {
    private(set) var willEndCount = 0
    private(set) var endCount = 0
    var onSessionWillEnd: () -> Void = {}
    var onSessionEnd: () -> Void = {}

    func sessionWillEnd() async {
        willEndCount += 1
        onSessionWillEnd()
    }

    func sessionDidEnd() {
        endCount += 1
        onSessionEnd()
    }
}
