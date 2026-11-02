import Foundation

nonisolated extension AppConfig {
    /// The one place that names the kind of build this is. Debug and Staging run from Xcode under a development
    /// profile (`lily.debug.entitlements`); Release alone is archived and distribution-signed.
    enum Build {
        enum Configuration: Sendable {
            case debug
            case staging
            case release
        }

        #if DEBUG
        static let configuration = Configuration.debug
        #elseif STAGING
        static let configuration = Configuration.staging
        #else
        static let configuration = Configuration.release
        #endif
    }
}
