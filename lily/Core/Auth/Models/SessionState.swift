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

    var isInsideApp: Bool {
        switch self {
        case .guest, .signedIn: true
        case .loading, .signedOut: false
        }
    }
}
