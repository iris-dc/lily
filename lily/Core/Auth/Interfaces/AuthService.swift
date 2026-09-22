import Foundation

/// Authentication boundary. Shaped after Amplify.Auth, so `CognitoAuthService` and `MockAuthService` are interchangeable.
protocol AuthService {
    /// Returns the current session if credentials are still valid, `nil` if nobody is signed in.
    func restoreSession() async throws -> AuthSession?
    /// Throws `AppError.emailNotConfirmed` for an account whose email was never confirmed, so the form can offer the code step.
    func signIn(with provider: AuthProvider) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> SignUpOutcome
    func confirmSignUp(email: String, code: String) async throws
    func resendConfirmationCode(email: String) async throws
    func signOut() async throws
}
