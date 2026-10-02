import Foundation

/// Which APNs host issued the device token: a debug build registers with Apple's sandbox, a release build with
/// production, and the backend must send to the matching host or the token is refused.
nonisolated enum PushEnvironment: String, Codable, Sendable {
    case sandbox
    case production

    static var current: PushEnvironment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }
}
