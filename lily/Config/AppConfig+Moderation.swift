import Foundation

nonisolated extension AppConfig {
    /// Reports, blocks and the legal documents: limits and the served pages' addresses.
    enum Moderation {
        static let commentMaxLength = 500
        /// The backend's `moderation.max-blocks`; the mock refuses past it so the popup can be seen.
        static let maxBlocks = 500
        /// What the mock `GET /api/me` answers as the current and accepted terms version (wire fields the client
        /// decodes and ignores: agreement is by use, stamped at account creation).
        static let mockTermsVersion = 1
        static let supportEmail = "support@iskra.red"
        /// Laurel serves the legal pages beside the API; they stay the canonical addresses (App Store Connect points
        /// at `privacyURL`), while the app reads the same documents in place.
        static let termsURL = API.productionBaseURL.appending(path: "terms")
        static let privacyURL = API.productionBaseURL.appending(path: "privacy")
    }

    /// The sign-up footnote's link tokens: not web addresses, only what its two link runs carry so a tap routes to
    /// the matching in-app screen (`LegalSheet.Document(agreementURL:)`); the served pages stay under `Moderation`.
    enum Legal {
        static let termsLink = URL(string: "iskra://legal/terms")!
        static let privacyLink = URL(string: "iskra://legal/privacy")!
    }
}

nonisolated extension AppConfig.API.Paths {
    /// The app only files reports; the per-report and suspension routes belong to Laurel's admin CLI.
    static let reports = "/api/reports"
    static let blocks = "/api/blocks"
    static let me = "/api/me"
    /// The advisory counts preview of account deletion; `DELETE` on `me` itself executes it.
    static let meDeletionPlan = "\(me)/deletion-plan"

    static func block(userID: String) -> String {
        "\(blocks)/\(userID)"
    }
}
