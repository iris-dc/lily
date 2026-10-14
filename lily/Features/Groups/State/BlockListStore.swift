import Foundation
import Observation

/// The caller's block list, the one source every room's `rows` reads (`ChatTimeline` hides a blocked sender's lines).
/// The backend answers the whole list on every route, so the store replaces, never merges. Loaded once per user from
/// the shell's sync; a failure is a warning and the next sync asks again, because the backend omits blocked senders
/// from its pages anyway: the list is a hint for cached rows and live lines, never shown as an error.
@Observable
final class BlockListStore: SessionObserver {
    private(set) var blockedUserIDs: Set<String> = []
    private var loadedUserID: String?
    private let load = SingleFlight()

    private let repository: any ModerationRepository
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(repository: any ModerationRepository, identity: any IdentityProvider, logger: any Logging) {
        self.repository = repository
        self.identity = identity
        self.logger = logger
    }

    /// Loads for the signed-in user unless already loaded for them; a guest has nothing to load and is cleared.
    func loadIfNeeded() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard loadedUserID != userID else { return }
        await reload()
    }

    /// A call made while one is in flight joins it; an answer that arrives after the caller signed out or changed is
    /// dropped.
    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        await load.run { [self] in await performLoad(for: userID) }
    }

    private func performLoad(for userID: String) async {
        do {
            let list = try await repository.blocks()
            guard identity.isStillCaller(userID, orDrop: "Block list answer", logger: logger) else { return }
            blockedUserIDs = list
            loadedUserID = userID
            logger.info(.groups, "Block list loaded: \(list.count) blocked")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.groups, "Loading the block list cancelled")
                return
            }
            guard identity.isStillCaller(userID, orDrop: "Block list answer", logger: logger) else { return }
            logger.warning(.groups, "Loading the block list failed: \(error)")
        }
    }

    /// Blocks the user and takes the backend's answer as the list. A refusal rethrows for the caller to report (a
    /// guest's write comes back as `.sessionExpired` from the client, like every write); an answer that arrives after
    /// the caller signed out or changed is dropped.
    func block(userID: String) async throws {
        let caller = identity.currentUserID
        let list = try await repository.block(userID: userID)
        if let caller, !identity.isStillCaller(caller, orDrop: "Block answer", logger: logger) { return }
        blockedUserIDs = list
        loadedUserID = caller
        logger.info(.groups, "User \(userID) blocked (\(list.count) blocked)")
    }

    func sessionDidEnd() {
        clear()
    }

    private func clear() {
        blockedUserIDs = []
        loadedUserID = nil
    }
}
