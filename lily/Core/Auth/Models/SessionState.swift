import Foundation

nonisolated enum SessionState: Hashable, Sendable {
    case loading
    case signedOut
    case guest
    case signedIn(AuthUser)

    var user: AuthUser? {
        if case .signedIn(let user) = self { return user }
        return nil
    }

    /// The one state that may ask for user-scoped content or write.
    var isSignedIn: Bool { user != nil }

    /// Whether the tabs are on screen: a guest or a signed-in user, never the launch or the landing, where a parked
    /// create would pop its sheet the moment the user entered.
    var showsShell: Bool {
        switch self {
        case .guest, .signedIn: true
        case .loading, .signedOut: false
        }
    }
}
