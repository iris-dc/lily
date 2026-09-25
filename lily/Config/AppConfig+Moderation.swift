import Foundation

nonisolated extension AppConfig {
    /// Reports, blocks and the terms: limits and the addresses the legal links open.
    enum Moderation {
        static let commentMaxLength = 500
        /// The backend's `moderation.max-blocks`; the mock refuses past it so the popup can be seen.
        static let maxBlocks = 500
        /// What the mock `GET /api/me` answers as the current and accepted terms version.
        static let mockTermsVersion = 1
        static let supportEmail = "support@iskra.red"
        static let termsURL = URL(string: "https://api.iskra.red/terms")!
        static let privacyURL = URL(string: "https://api.iskra.red/privacy")!
    }
}

nonisolated extension AppConfig.API.Paths {
    static let reports = "/api/reports"
    static let blocks = "/api/blocks"
    static let me = "/api/me"
    static let meTerms = "/api/me/terms"

    static func report(id: String) -> String {
        "\(reports)/\(id)"
    }

    static func block(userID: String) -> String {
        "\(blocks)/\(userID)"
    }

    static func suspension(userID: String) -> String {
        "/api/moderation/users/\(userID)/suspension"
    }
}

nonisolated extension AppConfig.API.Query {
    static let status = "status"
}
