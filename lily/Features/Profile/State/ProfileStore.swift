import Foundation
import Observation

/// The caller's `GET /api/profile`: the name other players see, loaded once per signed-in session when Profile opens
/// and replaced by the answer of a rename; a read that answers after a rename is dropped, the rename being the newer
/// name. A failed load is logged, never shown: the header draws a placeholder and the editor still works, since the
/// write does not need the read.
@Observable
final class ProfileStore: SessionObserver {
    private(set) var profile: Profile?
    private var loadedUserID: String?
    private let load = SingleFlight()

    private let repository: any ProfileRepository
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(repository: any ProfileRepository, identity: any IdentityProvider, logger: any Logging) {
        self.repository = repository
        self.identity = identity
        self.logger = logger
    }

    var displayName: String? { profile?.displayName }
    /// Whether the name is still the one the backend gave the account; the card nudges to pick one while it is.
    var isDefaultName: Bool { profile?.displayName == AppConfig.DisplayName.backendDefault }
    var isLoading: Bool { load.isRunning }

    /// Loads for the signed-in user unless already loaded for them; a guest has nothing to load and is cleared.
    func loadIfNeeded() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        guard profile == nil || loadedUserID != userID else {
            logger.debug(.cache, "Profile reused for the signed-in user")
            return
        }
        await load.run(key: userID) { [self] in await performLoad(for: userID) }
    }

    private func performLoad(for userID: String) async {
        do {
            let loaded = try await repository.profile()
            guard identity.isStillCaller(userID, orDrop: "Profile answer", logger: logger) else { return }
            // A rename that landed while this read was out holds the newer name; the read's answer is the older one.
            guard profile == nil || loadedUserID != userID else {
                logger.debug(.cache, "Profile answer superseded by a rename; dropped")
                return
            }
            profile = loaded
            loadedUserID = userID
            logger.info(.auth, "Profile loaded for user \(userID)")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.auth, "Loading the profile cancelled")
                return
            }
            logger.warning(.auth, "Loading the profile failed: \(error)")
        }
    }

    /// The one write of the name. The answer is the profile as the backend stored it and becomes the header's; an
    /// answer for a caller who signed out meanwhile is dropped. A failure that leaves the outcome unknown (a lost
    /// connection, a 5xx; Laurel commits before it answers) is settled by reading the profile back, so a rename that
    /// landed is never reported as failed. Every other failure goes to the caller, which shows it.
    func rename(to name: String) async throws -> Profile {
        guard let userID = identity.currentUserID else { throw AppError.sessionExpired }
        let updated: Profile
        do {
            updated = try await repository.updateDisplayName(name)
        } catch {
            guard let landed = await renamed(to: name, despite: error) else { throw error }
            updated = landed
        }
        if identity.isStillCaller(userID, orDrop: "Rename answer", logger: logger) {
            profile = updated
            loadedUserID = userID
            logger.info(.auth, "Display name updated for user \(userID)")
        }
        return updated
    }

    /// The profile read back after a failure that leaves the outcome unknown, when it shows the rename landed (the
    /// backend stores the name trimmed); `nil` for a refusal, which is never read back, a read that fails, or one that
    /// shows another name.
    private func renamed(to name: String, despite error: any Error) async -> Profile? {
        guard let appError = error as? AppError, appError.leavesRenameOutcomeUnknown else { return nil }
        do {
            let fresh = try await repository.profile()
            guard fresh.displayName == name.trimmed else {
                logger.debug(.auth, "Rename did not land despite \(appError); the profile reads another name")
                return nil
            }
            logger.info(.auth, "Rename landed despite \(appError); nothing to report")
            return fresh
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(.auth, "Could not check whether the rename landed after \(appError): \(error)")
            }
            return nil
        }
    }

    func sessionDidEnd() {
        logger.debug(.cache, "Profile cleared on sign-out")
        clear()
    }

    private func clear() {
        profile = nil
        loadedUserID = nil
    }
}

private extension AppError {
    /// A lost connection, or the route's fallback (what a 5xx without a code maps to): the PUT may have landed.
    var leavesRenameOutcomeUnknown: Bool { self == .network || self == .profileUpdateFailed }
}
