import Foundation
import Observation

/// Owns the group shown on the detail screen and the join, leave and delete actions on it. The server's answer
/// replaces the group here and in Mine through `MyGroupsStore`, whose write bumps `groupChanges`, which the lists
/// behind reload on.
@Observable
final class GroupDetailViewModel {
    private(set) var group: SportGroup
    let context: GroupDetailContext
    private(set) var isBusy = false
    /// The caller is out of the group and cannot see it any more (left a private group, or it was deleted).
    private(set) var isGone = false

    private let repository: any GroupRepository
    private let identity: any IdentityProvider
    private let store: MyGroupsStore
    private let reporter: GroupErrorReporter
    private let recorder: any InteractionRecorder
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let now: () -> Date
    private var hasRecordedView = false
    /// Where Mine stood (loads answered, changes written) when the detail last looked, so a store that has not moved
    /// since never replaces the group here.
    private var storeMark: (loads: Int, changes: Int)

    /// What the user asked for; an unknown outcome is settled by whether a fresh group shows it.
    private enum Intent {
        case join, leave, delete

        var name: String {
            switch self {
            case .join: "Join"
            case .leave: "Leave"
            case .delete: "Delete"
            }
        }
    }

    init(group: SportGroup,
         context: GroupDetailContext,
         repository: any GroupRepository,
         identity: any IdentityProvider,
         store: MyGroupsStore,
         reporter: GroupErrorReporter,
         recorder: any InteractionRecorder,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         now: @escaping () -> Date = { .now }) {
        self.group = group
        self.context = context
        self.repository = repository
        self.identity = identity
        self.store = store
        self.reporter = reporter
        self.recorder = recorder
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.now = now
        storeMark = (store.loadVersion, store.changesVersion)
    }

    var access: GroupAccess {
        GroupAccess(group: group, userID: identity.currentUserID)
    }

    /// Members, and every signed-in caller of a public group; guests never.
    var showsRoster: Bool {
        access.canSeeMembers(in: group)
    }

    /// Members get "Open chat", except from the chat itself (the path would cycle) and while chat is switched off.
    var showsOpenChat: Bool {
        access.canChat && context == .standalone && AppConfig.FeatureFlags.chat
    }

    var canReport: Bool {
        access.canReport(in: group)
    }

    /// What the detail's "Report group" files, like `TournamentDetailViewModel.reportTarget`.
    var reportTarget: ReportTarget {
        .group(id: group.id)
    }

    /// The toolbar menu is for members, and for a signed-in reader of a public group, who gets "Report group" alone.
    var showsMenu: Bool {
        access.canChat || canReport
    }

    /// One view per screen instance, however often the view's task restarts.
    func recordViewed() {
        guard !hasRecordedView else { return }
        hasRecordedView = true
        recorder.record(.groupViewed(group, at: now()))
    }

    func join() async {
        await update(.join) { try await repository.join(id: group.id) }
    }

    func leave() async {
        await update(.leave) { try await repository.leave(id: group.id) }
    }

    func delete() async {
        await update(.delete) { try await repository.delete(id: group.id) }
    }

    /// The group as a sibling screen just changed it (the roster removing a member, the edit sheet saving): shown
    /// here and written to Mine exactly like the detail's own writes.
    func accept(_ updated: SportGroup) {
        apply(updated)
    }

    /// Mine moved since the detail last looked (a reload, a live update, a sibling's write): the group as Mine now has it
    /// replaces the copy here. A group Mine does not hold (a non-member's public group) keeps its copy, and a group pushed
    /// fresher than Mine's copy is not replaced on appearance, because the store has not moved since.
    func refreshFromStore() {
        let mark = (loads: store.loadVersion, changes: store.changesVersion)
        guard mark != storeMark, !isGone else { return }
        storeMark = mark
        guard let stored = store.groups.first(where: { $0.id == group.id }) else { return }
        group = stored
    }

    /// One change at a time; `TRY_AGAIN` is repeated once. A refusal is shown after the group on screen was brought
    /// up to date, so the popup and the buttons agree. A failure that leaves the outcome unknown is shown only when
    /// the refetched group does not already show what was asked for: the backend commits before it answers.
    private func update(_ intent: Intent, _ change: () async throws -> SportGroup) async {
        guard !isBusy else { return }
        guard identity.currentUserID != nil else {
            logger.debug(.groups, "\(intent.name) ignored for a guest")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let updated = try await LostRace.attemptTwice(delay: tryAgainDelay,
                                                          logger: logger,
                                                          category: .groups,
                                                          retrying: "\(intent.name) for group \(group.id)",
                                                          change)
            apply(updated)
            logSuccess(intent, updated)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logFailure(intent, error)
            if await landed(intent, despite: error) {
                logger.info(.groups, "\(intent.name) landed for group \(group.id) despite \(error); nothing to report")
                return
            }
            reporter.report(error)
        }
    }

    /// Refetches when the outcome is worth another look and answers whether the fresh state already shows the intent.
    /// Refusals are never skipped, except `NOT_A_MEMBER` on a leave: the caller is out, which is what they asked.
    private func landed(_ intent: Intent, despite error: any Error) async -> Bool {
        guard let appError = error as? AppError, appError.needsGroupRefresh else { return false }
        let fresh = await refetch(after: appError)
        guard appError.leavesOutcomeUnknown || (intent == .leave && appError == .notAMember) else { return false }
        switch (intent, fresh) {
        case (.join, .fresh(let group)): return group.isMember
        case (.leave, .fresh(let group)): return !group.isMember
        case (.leave, .gone): return true
        case (.delete, .fresh(let group)): return group.isDeleted
        case (.delete, .gone): return true
        default: return false
        }
    }

    private enum Refetch {
        case fresh(SportGroup)
        /// `GROUP_NOT_FOUND`: deleted, or private and the caller is no longer in it.
        case gone
        case unavailable
    }

    private func refetch(after error: AppError) async -> Refetch {
        do {
            let fresh = try await repository.group(id: group.id)
            apply(fresh)
            logger.info(.groups, "Refreshed group \(group.id) after \(error)")
            return .fresh(fresh)
        } catch AppError.groupNotFound {
            markGone()
            logger.info(.groups, "Group \(group.id) is gone for the caller after \(error)")
            return .gone
        } catch {
            if !AppError.isCancellation(error) {
                logger.warning(.groups, "Could not refresh group \(group.id) after \(error)")
            }
            return .unavailable
        }
    }

    private func apply(_ updated: SportGroup) {
        group = updated
        if updated.isMember, !updated.isDeleted {
            store.add(updated)
        } else if store.groups.contains(where: { $0.id == updated.id }) {
            store.replace(updated)
        }
        isGone = updated.isDeleted
    }

    private func markGone() {
        isGone = true
        store.remove(id: group.id)
    }

    private func logSuccess(_ intent: Intent, _ updated: SportGroup) {
        switch intent {
        case .join: logger.info(.groups, "Joined group \(updated.id) (public)")
        case .leave: logger.info(.groups, "Left group \(updated.id)")
        case .delete: logger.info(.groups, "Group \(updated.id) deleted")
        }
    }

    /// A refusal is an expected product state (the group moved on) and stays a warning; anything else is an error.
    private func logFailure(_ intent: Intent, _ error: any Error) {
        let message = "\(intent.name) failed for group \(group.id): \(error)"
        if let appError = error as? AppError, appError.isGroupConflict {
            logger.warning(.groups, message)
        } else {
            logger.error(.groups, message)
        }
    }
}

private extension AppError {
    /// Refusals that mean the group changed under the caller, or the caller's standing did.
    var isGroupConflict: Bool {
        switch self {
        case .groupFull, .bannedFromGroup, .notAMember, .ownerCannotLeave, .membershipLimitReached, .tryAgain,
             .groupNotFound, .insufficientRole, .termsRequired:
            true
        default:
            false
        }
    }

    /// A 500 or a lost connection after the backend may already have committed the change.
    var leavesOutcomeUnknown: Bool {
        self == .groupActionFailed || self == .network
    }

    /// Worth another look: every refusal but the terms gate (nothing about the group changed) and every unknown outcome.
    var needsGroupRefresh: Bool {
        (isGroupConflict && self != .termsRequired) || leavesOutcomeUnknown
    }
}
