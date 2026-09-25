import Foundation

/// The caller's own account as the backend sees it: operator status, the terms owed, where live chat connects.
protocol MeRepository {
    func me() async throws -> Account
    /// `version` must be the current `Account.termsVersion`.
    func acceptTerms(version: Int) async throws -> TermsAcceptance
}
