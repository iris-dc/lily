import Foundation
import Observation

/// What an invite leads to, and the join behind it. Guests see the preview and sign in first; the code stays put
/// through the sign-in, so `join()` is simply called again afterwards. A redeemed group goes into Mine and its chat
/// opens, then the sheet is told to dismiss.
@Observable
final class InvitePreviewViewModel {
    let code: InviteCode
    private(set) var preview: InvitePreview?
    private(set) var isLoading = false
    /// The preview could not be fetched; the popup said why.
    private(set) var loadFailed = false
    private(set) var isJoining = false
    private(set) var joinedGroup: SportGroup?

    private let invites: any InviteRepository
    private let groups: any GroupRepository
    private let identity: any IdentityProvider
    private let store: MyGroupsStore
    private let navigation: AppNavigation
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let onJoined: @MainActor (SportGroup) -> Void

    init(code: InviteCode,
         invites: any InviteRepository,
         groups: any GroupRepository,
         identity: any IdentityProvider,
         store: MyGroupsStore,
         navigation: AppNavigation,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         onJoined: @escaping @MainActor (SportGroup) -> Void) {
        self.code = code
        self.invites = invites
        self.groups = groups
        self.identity = identity
        self.store = store
        self.navigation = navigation
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.onJoined = onJoined
    }

    /// Joining needs an account; the sheet presents sign-in and calls `join()` once it succeeded.
    var needsSignIn: Bool { identity.currentUserID == nil }

    /// The preview's group; `nil` until loaded.
    var groupName: String? { preview?.group.name }

    var canJoin: Bool { preview != nil && !isJoining && joinedGroup == nil }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            preview = try await invites.preview(code: code)
            logger.info(.groups, "Invite previewed for group \(preview?.group.id ?? "?")")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.groups, "Invite preview failed: \(error)")
            loadFailed = true
            reporter.report(error)
        }
    }

    /// Redeems the code; `TRY_AGAIN` is repeated once. An answer that never arrived is settled by fetching the
    /// group: a membership there means the join landed and nothing is reported.
    func join() async {
        guard canJoin, let preview, !needsSignIn else { return }
        isJoining = true
        defer { isJoining = false }
        do {
            let group = try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: logRetry) {
                try await invites.redeem(code: code)
            }
            accept(group)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Invite redeem failed for group \(preview.group.id): \(error)")
            if let landed = await membership(in: preview.group.id, despite: error) {
                logger.info(.groups, "Invite redeem landed for group \(landed.id) despite \(error)")
                accept(landed)
            } else {
                reporter.report(error)
            }
        }
    }

    private func accept(_ group: SportGroup) {
        joinedGroup = group
        store.add(group)
        logger.info(.groups, "Invite redeemed for group \(group.id)")
        navigation.open(chat: group)
        onJoined(group)
    }

    /// After a `.network` or `.groupActionFailed` the backend may have admitted the caller before the answer was
    /// lost; the group answers with a membership when it did. Anything else keeps the failure.
    private func membership(in groupID: String, despite error: any Error) async -> SportGroup? {
        guard let appError = error as? AppError, appError == .network || appError == .groupActionFailed else { return nil }
        do {
            let fresh = try await groups.group(id: groupID)
            return fresh.isMember ? fresh : nil
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(.groups, "Could not check whether the redeem landed after \(appError)")
            }
            return nil
        }
    }

    private func logRetry() {
        logger.info(.groups, "Invite redeem lost a race; retrying once")
    }
}
