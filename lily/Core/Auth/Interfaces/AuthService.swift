import Foundation

/// Authentication boundary. Shaped after Amplify.Auth so `CognitoAuthService` can replace the mock unchanged.
protocol AuthService {
    /// Returns the current session if credentials are still valid, `nil` if nobody is signed in.
    func restoreSession() async throws -> AuthSession?
    func signIn(with provider: AuthProvider) async throws -> AuthSession
    func signUp(email: String, password: String) async throws
    func signOut() async throws
}
