import Foundation

/// The backend's `GET /api/me`: what the caller is allowed to do and what they still owe. `Me` would be the
/// endpoint's name, but two letters are below the project's minimum for a type name. A missing `attachmentsEnabled`
/// reads as off: the field arrived with attachments, and an older backend has no bucket to take them.
nonisolated struct Account: Hashable, Codable, Sendable {
    let userId: String
    let isOperator: Bool
    /// The terms version every write requires accepted.
    let termsVersion: Int
    let acceptedTermsVersion: Int?
    /// Where live chat connects; absent while the backend has no realtime API configured.
    let realtimeEndpoint: URL?
    /// Whether the backend takes chat attachments (it has a bucket); the composer hides its attach button otherwise.
    let attachmentsEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case userId, isOperator, termsVersion, acceptedTermsVersion, realtimeEndpoint, attachmentsEnabled
    }

    init(userId: String,
         isOperator: Bool = false,
         termsVersion: Int,
         acceptedTermsVersion: Int? = nil,
         realtimeEndpoint: URL? = nil,
         attachmentsEnabled: Bool = false) {
        self.userId = userId
        self.isOperator = isOperator
        self.termsVersion = termsVersion
        self.acceptedTermsVersion = acceptedTermsVersion
        self.realtimeEndpoint = realtimeEndpoint
        self.attachmentsEnabled = attachmentsEnabled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(userId: try container.decode(String.self, forKey: .userId),
                  isOperator: try container.decode(Bool.self, forKey: .isOperator),
                  termsVersion: try container.decode(Int.self, forKey: .termsVersion),
                  acceptedTermsVersion: try container.decodeIfPresent(Int.self, forKey: .acceptedTermsVersion),
                  realtimeEndpoint: try container.decodeIfPresent(URL.self, forKey: .realtimeEndpoint),
                  attachmentsEnabled: try container.decodeIfPresent(Bool.self, forKey: .attachmentsEnabled) ?? false)
    }

    var termsAccepted: Bool { (acceptedTermsVersion ?? 0) >= termsVersion }

    func acceptingTerms(_ acceptance: TermsAcceptance) -> Account {
        Account(userId: userId,
                isOperator: isOperator,
                termsVersion: termsVersion,
                acceptedTermsVersion: acceptance.acceptedTermsVersion,
                realtimeEndpoint: realtimeEndpoint,
                attachmentsEnabled: attachmentsEnabled)
    }
}

/// Body of `PUT /api/me/terms`; the version must be the one `Account.termsVersion` names.
nonisolated struct TermsAcceptancePayload: Encodable, Equatable, Sendable {
    let version: Int
}

/// Answer of `PUT /api/me/terms`.
nonisolated struct TermsAcceptance: Hashable, Codable, Sendable {
    let acceptedTermsVersion: Int
    let acceptedTermsAt: Date
}
