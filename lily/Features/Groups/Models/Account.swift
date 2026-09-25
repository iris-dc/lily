import Foundation

/// The backend's `GET /api/me`: what the caller is allowed to do and what they still owe. `Me` would be the
/// endpoint's name, but two letters are below the project's minimum for a type name.
nonisolated struct Account: Hashable, Codable, Sendable {
    let userId: String
    let isOperator: Bool
    /// The terms version every write requires accepted.
    let termsVersion: Int
    let acceptedTermsVersion: Int?
    /// Where live chat connects; absent while the backend has no realtime API configured.
    let realtimeEndpoint: URL?

    init(userId: String,
         isOperator: Bool = false,
         termsVersion: Int,
         acceptedTermsVersion: Int? = nil,
         realtimeEndpoint: URL? = nil) {
        self.userId = userId
        self.isOperator = isOperator
        self.termsVersion = termsVersion
        self.acceptedTermsVersion = acceptedTermsVersion
        self.realtimeEndpoint = realtimeEndpoint
    }

    var termsAccepted: Bool { (acceptedTermsVersion ?? 0) >= termsVersion }

    func acceptingTerms(_ acceptance: TermsAcceptance) -> Account {
        Account(userId: userId,
                isOperator: isOperator,
                termsVersion: termsVersion,
                acceptedTermsVersion: acceptance.acceptedTermsVersion,
                realtimeEndpoint: realtimeEndpoint)
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
