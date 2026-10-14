import Foundation
import Observation

/// The caller's groups (Mine, direct conversations included), kept for the app's lifetime because more than one screen
/// needs them: the create form's group picker, the invite flow, the room subscriptions and the tab badge. A tab-local
/// view model would exist only once the user visited the tab. Loads through `StoreLoader` (the events lists' staleness
/// rules, one request at a time, judged against the group-changes version), so a tab that reappears reuses what it
/// already has.
@Observable
final class MyGroupsStore: SessionObserver {
    /// Most recently active first, as the backend orders Mine.
    private(set) var groups: [SportGroup] = []
    /// Counts the loads that answered. The unread set follows this, not `groups`: a local `add` or `replace` carries
    /// membership flags read before the rooms were, and would bring a read room's dot back.
    private(set) var loadVersion = 0
    private let loader: StoreLoader

    private let repository: any GroupRepository
    private let identity: any IdentityProvider
    private let changes: ChangeTracker
    /// The group-changes version as of now, for screens that decide staleness against it (Discover behind the carousel).
    var changesVersion: Int { changes.version }
    private let logger: any Logging

    init(repository: any GroupRepository,
         identity: any IdentityProvider,
         changes: ChangeTracker,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.identity = identity
        self.changes = changes
        self.logger = logger
        loader = StoreLoader(noun: "groups",
                             category: .groups,
                             identity: identity,
                             errorCenter: errorCenter,
                             logger: logger,
                             now: now,
                             version: { changes.version })
    }

    /// True from a failed load until the next successful one.
    var loadFailed: Bool { loader.loadFailed }
    /// An answer landed at least once since the last reset; `loadFailed` is the other way a load ends.
    var hasLoaded: Bool { loader.hasLoaded }
    var isLoading: Bool { loader.isLoading }

    /// The communities in Mine (kind `group`): what "your groups" means on Home, in the event form and anywhere else a
    /// group is a community; conversations and rooms of a kind this build does not know stay out. `groups` (everything)
    /// feeds the Chats tab, the unread set and the room subscriptions.
    var communities: [SportGroup] {
        groups.filter(\.isCommunity)
    }

    /// The groups the caller may create a game in, for the create form's picker.
    var eligibleForEvents: [SportGroup] {
        let userID = identity.currentUserID
        return communities.filter { GroupAccess(group: $0, userID: userID).canCreateEvents(in: $0) }
    }

    /// Loads once per `AppConfig.Lists.staleAfter`, or sooner when a group changed elsewhere or the caller
    /// changed; after a failed load it waits `AppConfig.Lists.retryAfterFailure` unless one of those happened.
    /// A guest has no groups: the list is cleared without a request.
    func loadIfStale() async {
        guard identity.currentUserID != nil else {
            clear()
            return
        }
        await loader.loadIfStale(fetch: fetchMine, apply: applyMine)
    }

    /// Always asks the backend (pull-to-refresh, the resume protocol). A call made while one is in flight joins it (one
    /// for another user waits it out and then loads for them); an answer for a caller who signed out or changed is
    /// dropped; a change recorded while the request was out (a local `add`, `remove` or `replace`, a detail's write) is
    /// newer than the answer, so the answer is applied and the load runs once more.
    func reload() async {
        guard identity.currentUserID != nil else {
            clear()
            return
        }
        await loader.reload(fetch: fetchMine, apply: applyMine)
    }

    private func fetchMine() async throws -> [SportGroup] {
        try await repository.groups(in: .mine, cursor: nil, near: nil).items
    }

    /// The answer replaces what is held; `loadVersion` tells the unread set a load, not a local change, did it.
    private func applyMine(_ loaded: [SportGroup]) {
        groups = loaded
        loadVersion += 1
        logger.info(.groups, "Loaded \(groups.count) groups")
    }

    /// A group the caller just joined or created, placed where a reload would put it under `SportGroup.mineOrder`. The
    /// backend's Mine index is eventually consistent, so a reload right after a join might still miss it; this is what
    /// shows it at once.
    func add(_ group: SportGroup) {
        groups.removeAll { $0.id == group.id }
        groups.insert(group, at: groups.firstIndex { SportGroup.mineOrder(group, $0) } ?? groups.endIndex)
        recordChange("Group \(group.id) added to Mine")
    }

    /// The group as a screen just changed it. One the caller is no longer in leaves the list. One not held is never
    /// inserted (the realtime refetch after a local drop relies on that), but sibling screens still learn of the change.
    func replace(_ group: SportGroup) {
        guard group.isMember, !group.isDeleted else {
            remove(id: group.id)
            return
        }
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else {
            recordChange("Group \(group.id) not in Mine; nothing replaced")
            return
        }
        groups[index] = group
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
        loader.acknowledge(version: changes.version)
        logger.debug(.cache, "\(what); sibling screens invalidated")
    }

    private func clear() {
        groups = []
        loader.reset()
    }
}
