import Foundation

/// The app's version as the backend sees it in `X-App-Version`. Read once from the bundle, injectable for tests.
nonisolated struct AppVersion: Equatable, Sendable {
    let marketing: String
    let build: String

    init(marketing: String, build: String) {
        self.marketing = marketing
        self.build = build
    }

    /// A component the dictionary lacks (a bundle without a version) becomes `AppConfig.Version.unknownComponent`.
    init(infoDictionary: [String: Any]) {
        let keys = AppConfig.Version.self
        self.init(marketing: infoDictionary[keys.marketingKey] as? String ?? keys.unknownComponent,
                  build: infoDictionary[keys.buildKey] as? String ?? keys.unknownComponent)
    }

    /// `1.0 (42)`: the marketing version, then the build number in parentheses.
    var headerValue: String {
        "\(marketing) (\(build))"
    }

    static func current(bundle: Bundle = .main) -> AppVersion {
        AppVersion(infoDictionary: bundle.infoDictionary ?? [:])
    }
}
