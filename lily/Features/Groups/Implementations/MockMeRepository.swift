import Foundation

/// Answers a signed-in mock user: an operator when signed in as the Apple tester (so the operator queue can be seen),
/// no realtime endpoint, attachments on (the mock store stands in for the bucket), and the terms accepted unless the
/// app was started with `-mock-terms-pending`, which makes `me()` owe them until the first acceptance of the run.
final class MockMeRepository: MeRepository {
    /// Whether `me()` answers no accepted terms version; `acceptTerms` ends it for the run.
    private(set) var owesTerms: Bool
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(identity: any IdentityProvider,
         logger: any Logging,
         now: @escaping () -> Date = { .now },
         termsPending: Bool = false) {
        self.identity = identity
        self.logger = logger
        self.now = now
        owesTerms = termsPending
    }

    func me() async throws -> Account {
        guard let userID = identity.currentUserID else { throw AppError.sessionExpired }
        logger.debug(.groups, "Mock me served")
        return Account(userId: userID,
                       isOperator: userID == MockUsers.user(for: .apple).id,
                       termsVersion: AppConfig.Moderation.mockTermsVersion,
                       acceptedTermsVersion: owesTerms ? nil : AppConfig.Moderation.mockTermsVersion,
                       attachmentsEnabled: true)
    }

    func acceptTerms(version: Int) async throws -> TermsAcceptance {
        owesTerms = false
        logger.info(.groups, "Mock terms v\(version) accepted")
        return TermsAcceptance(acceptedTermsVersion: version, acceptedTermsAt: now())
    }
}
