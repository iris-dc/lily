import Foundation

/// Hands the API client the credential to send. Read per request, so a token refreshed or dropped meanwhile is picked up.
protocol AuthTokenProvider {
    /// The signed-in user's Cognito access token, or `nil` for a guest (and when no token can be produced: the request
    /// then goes out without one and the backend's 401 becomes `AppError.sessionExpired`).
    func accessToken() async -> String?
    /// A token refreshed at the pool even when the current one is still valid; `nil` for a guest or when the refresh
    /// failed. Only the realtime connection uses it (a reconnect before expiry, a 401 at connect): the REST client
    /// keeps `accessToken()`, which refreshes only an expired token.
    func freshAccessToken() async -> String?
}
