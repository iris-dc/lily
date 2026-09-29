import Foundation
import Observation

/// The caller's groups (Mine), kept for the app's lifetime because more than one screen needs them: the create
/// form's group picker, the invite flow and, later, the room subscriptions and the tab badge. A tab-local view model
/// would exist only once the user visited the tab. Follows the events lists' staleness rules through
/// `ContentFreshness`, so a tab that reappears reuses what it already has.
@Observable
final class MyGroupsStore: SessionObserver {
    /// Most recently active first, as the backend orders Mine.
    private(set) var groups: [SportGroup] = []
    private let load = SingleFlight()
    /// Counts the loads that answered. The unread set follows this, not `groups`: a local `add` or `replace` carries
    /// membership flags read before the rooms were, and would bring a read room's dot back.
    private(set) var loadVersion = 0
    private var freshness = ContentFreshness(staleAfter: AppConfig.Groups.listStaleAfter,
                                             retryAfterFailure: AppConfig.Groups.retryAfterFailure)

    private let repository: any GroupRepository
    private let identity: any IdentityProvider
    private let changes: ChangeTracker
    /// The group-changes version as of now, for screens that decide staleness against it (Discover behind the carousel).
    var changesVersion: Int { changes.version }
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date

    init(repository: any GroupRepository,
         identity: any IdentityProvider,
         changes: ChangeTracker,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.identity = identity
        self.changes = changes
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
    }

    /// True from a failed load until the next successful one.
    var loadFailed: Bool { freshness.loadFailed }
    var isLoading: Bool { load.isRunning }

    /// The groups the caller may create a game in, for the create form's picker.
    var eligibleForEvents: [SportGroup] {
        let userID = identity.currentUserID
        return groups.filter { GroupAccess(group: $0, userID: userID).canCreateEvents(in: $0) }
    }

    /// Loads once per `AppConfig.Groups.listStaleAfter`, or sooner when a group changed elsewhere or the caller
    /// changed; after a failed load it waits `AppConfig.Groups.retryAfterFailure` unless one of those happened.
    /// A guest has no groups: the list is cleared without a request.
    func loadIfStale() async {
        guard identity.currentUserID != nil else {
            clear()
            return
        }
        let version = changes.version
        let userID = identity.currentUserID
        guard !freshness.isWaitingToRetry(now: now(), version: version, userID: userID) else {
            logger.debug(.cache, "Groups failed to load recently; not retrying yet")
            return
        }
        guard let reason = freshness.stalenessReason(now: now(), version: version, userID: userID) else {
            logger.debug(.cache, "Groups are fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Groups are stale (\(reason)); reloading")
        await reload()
    }

    /// Always asks the backend (pull-to-refresh, the resume protocol). A call made while one is in flight joins it; an
    /// answer that arrives after the caller signed out or changed is dropped.
    func reload() async {
        guard let userID = identity.currentUserID else {
            clear()
            return
        }
        await load.run { [self] in await performLoad(for: userID) }
    }

    private func performLoad(for userID: String) async {
        let version = changes.version
        do {
            let loaded = try await repository.groups(in: .mine, cursor: nil).items
            guard identity.isStillCaller(userID, orDrop: "Groups answer", logger: logger) else { return }
            groups = loaded
            loadVersion += 1
            freshness.recordSuccess(at: now(), version: version, userID: userID)
            logger.info(.groups, "Loaded \(groups.count) groups")
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.groups, "Loading groups cancelled")
                return
            }
            guard identity.isStillCaller(userID, orDrop: "Groups answer", logger: logger) else { return }
            freshness.recordFailure(at: now(), version: version, userID: userID)
            logger.error(.groups, "Loading groups failed: \(error)")
            errorCenter.report(error)
        }
    }

    /// A group the caller just joined or created, placed where a reload would put it. The backend's Mine index is
    /// eventually consistent, so a reload right after a join might still miss it; this is what shows it at once.
    func add(_ group: SportGroup) {
        groups.removeAll { $0.id == group.id }
        groups.insert(group, at: groups.firstIndex { $0.lastActivityAt < group.lastActivityAt } ?? groups.endIndex)
        recordChange("Group \(group.id) added to Mine")
    }

    /// The group as a screen just changed it. One the caller is no longer in leaves the list.
    func replace(_ group: SportGroup) {
        guard group.isMember, !group.isDeleted else {
            remove(id: group.id)
            return
        }
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        }
        recordChange("Group \(group.id) replaced in Mine")
    }

    /// A `group_updated` broadcast: the shared fields change, the caller's membership stays. A group not in Mine is
    /// not the caller's to show.
    func apply(_ update: SportGroup) {
        guard let stored = groups.first(where: { $0.id == update.id }) else { return }
        replace(update.keepingMembership(of: stored))
    }

    func remove(id: String) {
        groups.removeAll { $0.id == id }
        recordChange("Group \(id) removed from Mine")
    }

    func sessionDidEnd() {
        clear()
        logger.debug(.cache, "Groups cleared on sign-out")
    }

    /// Recorded so every other group screen reloads on its next appearance; this store already shows it and does not.
    private func recordChange(_ what: String) {
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "\(what); sibling screens invalidated")
    }

    private func clear() {
        groups = []
        freshness.reset()
    }
}
