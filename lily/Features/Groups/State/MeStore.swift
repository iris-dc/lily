import Foundation
import Observation

/// The caller's `GET /api/me`, loaded once per signed-in session: whether the terms are owed, whether they operate,
/// and where live chat connects. A failed load is logged and not shown: a write the terms gate refuses reaches the
/// popup on its own and re-raises the sheet through `noteTermsRequired()`.
@Observable
final class MeStore: SessionObserver {
    private(set) var account: Account?
    /// Set when a write answered `TERMS_REQUIRED` (a race, or a version bump since the load); cleared by acceptance.
    private(set) var termsOutdated = false
    private var loadedUserID: String?

    private let repository: any MeRepository
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(repository: any MeRepository, identity: any IdentityProvider, errorCenter: ErrorCenter, logger: any Logging) {
        self.repository = repository
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
    }

    /// Whether the current terms are still owed: the backend said so on the load, or a write was refused since.
    var needsTerms: Bool { termsOutdated || account.map { !$0.termsAccepted } ?? false }
    var isOperator: Bool { account?.isOperator ?? false }
    var realtimeEndpoint: URL? { account?.realtimeEndpoint }

    /// Loads for the signed-in user unless already loaded for them; a guest has nothing to load and is cleared.
    func loadIfNeeded() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard account == nil || loadedUserID != userID else { return }
        await reload()
    }

    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        do {
            account = try await repository.me()
            loadedUserID = userID
            logger.info(.groups, "Account loaded; terms accepted: \(account?.termsAccepted ?? false)")
        } catch {
            logger.warning(.groups, "Loading the account failed: \(error)")
        }
    }

    /// Accepts the version the backend named. `false` when it could not be recorded; the popup says why.
    func acceptTerms() async -> Bool {
        guard let account else { return false }
        do {
            let acceptance = try await repository.acceptTerms(version: account.termsVersion)
            self.account = account.acceptingTerms(acceptance)
            termsOutdated = false
            logger.info(.groups, "Terms accepted (version \(acceptance.acceptedTermsVersion))")
            return true
        } catch {
            logger.error(.groups, "Accepting the terms failed: \(error)")
            errorCenter.report(error)
            return false
        }
    }

    func noteTermsRequired() {
        termsOutdated = true
    }

    func sessionDidEnd() {
        clear()
    }

    private func clear() {
        account = nil
        loadedUserID = nil
        termsOutdated = false
    }
}
