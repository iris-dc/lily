import Foundation

/// Answers a signed-in mock user: terms accepted, an operator when signed in as the Apple tester (so the operator
/// queue can be seen), no realtime endpoint.
final class MockMeRepository: MeRepository {
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func me() async throws -> Account {
        guard let userID = identity.currentUserID else { throw AppError.sessionExpired }
        logger.debug(.groups, "Mock me served")
        return Account(userId: userID,
                       isOperator: userID == MockUsers.user(for: .apple).id,
                       termsVersion: AppConfig.Moderation.mockTermsVersion,
                       acceptedTermsVersion: AppConfig.Moderation.mockTermsVersion)
    }

    func acceptTerms(version: Int) async throws -> TermsAcceptance {
        TermsAcceptance(acceptedTermsVersion: version, acceptedTermsAt: now())
    }
}
