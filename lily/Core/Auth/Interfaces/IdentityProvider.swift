import Foundation

/// Who the app acts for right now. Read at the moment of use, so a sign-in or sign-out shows on the very next call.
protocol IdentityProvider {
    /// The signed-in user's id (the Cognito `sub`), or `nil` for guests.
    var currentUserID: String? { get }
}
