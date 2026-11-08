import Foundation
import Observation

/// The caller's `GET /api/me`, loaded once per signed-in session: operator status, where live chat connects and
/// whether the backend takes attachments. A failed load is logged and not shown: the screens treat a missing account
/// as "not known yet" and the next `loadIfNeeded` tries again. The answer's terms fields stay on the wire and are
/// ignored: the app never prompts for terms — agreement is by use, stamped by the backend at account creation
/// (owner decision 2026-11-08).
@Observable
final class MeStore: SessionObserver {
    private(set) var account: Account?
    private var loadedUserID: String?
    private let load = SingleFlight()

    private let repository: any MeRepository
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(repository: any MeRepository, identity: any IdentityProvider, logger: any Logging) {
        self.repository = repository
        self.identity = identity
        self.logger = logger
    }

    var realtimeEndpoint: URL? { account?.realtimeEndpoint }
    /// Whether the backend takes chat attachments; off until the account is known, so no button shows for nothing.
    var attachmentsEnabled: Bool { account?.attachmentsEnabled ?? false }
    var isLoading: Bool { load.isRunning }

    /// Loads for the signed-in user unless already loaded for them; a guest has nothing to load and is cleared.
    func loadIfNeeded() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard account == nil || loadedUserID != userID else {
            logger.debug(.cache, "Account reused for the signed-in user")
            return
        }
        await reload()
    }

    /// A call for the same user joins the run in flight; one for another user waits it out and then loads for them; an
    /// answer for a caller who signed out or changed is dropped.
    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        await load.run(key: userID) { [self] in await performLoad(for: userID) }
    }

    private func performLoad(for userID: String) async {
        do {
            let loaded = try await repository.me()
            guard identity.isStillCaller(userID, orDrop: "Account answer", logger: logger) else { return }
            account = loaded
            loadedUserID = userID
            logger.info(.groups, "Account loaded")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.groups, "Loading the account cancelled")
                return
            }
            guard identity.isStillCaller(userID, orDrop: "Account answer", logger: logger) else { return }
            logger.warning(.groups, "Loading the account failed: \(error)")
        }
    }

    func sessionDidEnd() {
        logger.debug(.cache, "Account cleared on sign-out")
        clear()
    }

    private func clear() {
        account = nil
        loadedUserID = nil
    }
}
