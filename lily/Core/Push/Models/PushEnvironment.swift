import Foundation

/// Which APNs host issued the device token: the `aps-environment` of the profile the build is signed with. A build run
/// from Xcode (Debug, Staging) is development-signed and holds a sandbox token, an archived Release a production one;
/// the backend must send to the matching host or the token is refused.
nonisolated enum PushEnvironment: String, Codable, Sendable {
    case sandbox
    case production

    static var current: PushEnvironment {
        forBuild(AppConfig.Build.configuration)
    }

    static func forBuild(_ configuration: AppConfig.Build.Configuration) -> PushEnvironment {
        configuration == .release ? .production : .sandbox
    }
}
