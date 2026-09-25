import Foundation
import Observation

/// The roster of a group and what the caller may do to each row. Admins also see the banned list. The caller's own
/// row is never offered an action: leaving is the detail's, and the backend refuses a self-target anyway.
@Observable
final class MembersViewModel {
    /// What an admin or owner can do to another member's row, in menu order.
    enum MemberAction: Hashable, CaseIterable {
        case makeAdmin, removeAdmin, remove, ban

        var title: String {
            switch self {
            case .makeAdmin: AppBranding.Groups.makeAdmin
            case .removeAdmin: AppBranding.Groups.removeAdmin
            case .remove: AppBranding.Groups.removeMember
            case .ban: AppBranding.Groups.banMember
            }
        }
    }

    private(set) var group: SportGroup
    private(set) var members: [GroupMember] = []
    private(set) var bans: [GroupMember] = []
    private(set) var isLoading = false
    private(set) var isBusy = false

    private let repository: any GroupRepository
    private let identity: any IdentityProvider
    private let reporter: GroupErrorReporter
    private let logger: any Logging
    private let tryAgainDelay: Duration
    private let onChange: @MainActor (SportGroup) -> Void

    init(group: SportGroup,
         repository: any GroupRepository,
         identity: any IdentityProvider,
         reporter: GroupErrorReporter,
         logger: any Logging,
         tryAgainDelay: Duration = AppConfig.API.tryAgainDelay,
         onChange: @escaping @MainActor (SportGroup) -> Void) {
        self.group = group
        self.repository = repository
        self.identity = identity
        self.reporter = reporter
        self.logger = logger
        self.tryAgainDelay = tryAgainDelay
        self.onChange = onChange
    }

    var access: GroupAccess { GroupAccess(group: group, userID: identity.currentUserID) }

    /// The banned section is for those who can ban.
    var showsBans: Bool { access.canEdit }

    func isSelf(_ member: GroupMember) -> Bool {
        member.userId == identity.currentUserID
    }

    /// The actions the caller may take on `member`; empty for the caller's own row and for rows above their reach.
    func actions(for member: GroupMember) -> [MemberAction] {
        guard !isSelf(member) else { return [] }
        return MemberAction.allCases.filter { allows($0, on: member) }
    }

    /// The roster, and the banned list when the caller may act on it.
    func load() async {
        guard access.canSeeMembers else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            members = try await repository.members(id: group.id)
            if showsBans { bans = try await repository.bans(id: group.id) }
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Loading members of group \(group.id) failed: \(error)")
            reporter.report(error)
        }
    }

    func perform(_ action: MemberAction, on member: GroupMember) async {
        guard actions(for: member).contains(action) else { return }
        switch action {
        case .makeAdmin: await setRole(.admin, of: member)
        case .removeAdmin: await setRole(.member, of: member)
        case .remove: await remove(member)
        case .ban: await ban(member)
        }
    }

    func unban(_ member: GroupMember) async {
        await act("Unban") {
            try await repository.unban(id: group.id, userID: member.userId)
            bans.removeAll { $0.userId == member.userId }
            logger.info(.groups, "Member \(member.userId) unbanned in group \(group.id)")
        }
    }

    private func setRole(_ role: MemberRole, of member: GroupMember) async {
        await act("Role change") {
            let changed = try await repository.setRole(id: group.id, userID: member.userId, role)
            replaceRow(changed)
            logger.info(.groups, "Member \(member.userId) in group \(group.id) is now \(role.rawValue)")
        }
    }

    private func remove(_ member: GroupMember) async {
        await act("Remove") {
            let updated = try await repository.remove(id: group.id, userID: member.userId)
            dropRow(member, updated: updated)
            logger.info(.groups, "Member \(member.userId) removed from group \(group.id)")
        }
    }

    /// A ban is a role change to `banned`: the row moves from the roster to the banned list.
    private func ban(_ member: GroupMember) async {
        await act("Ban") {
            let banned = try await repository.setRole(id: group.id, userID: member.userId, .banned)
            dropRow(member, updated: nil)
            bans.insert(banned, at: 0)
            logger.info(.groups, "Member \(member.userId) banned in group \(group.id)")
        }
    }

    /// One action at a time; `TRY_AGAIN` is repeated once; a dismissed screen stays quiet; a failure goes to the popup.
    /// Every action is safe to repeat, so a refusal needs no second-guessing: the next load shows the roster as it is.
    private func act(_ name: String, _ change: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await LostRace.attemptTwice(delay: tryAgainDelay, onRetry: { logRetry(name) }, change)
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "\(name) failed in group \(group.id): \(error)")
            reporter.report(error)
        }
    }

    private func logRetry(_ name: String) {
        logger.info(.groups, "\(name) lost a race in group \(group.id); retrying once")
    }

    private func allows(_ action: MemberAction, on member: GroupMember) -> Bool {
        switch action {
        case .makeAdmin: access.canChangeRoles && member.role == .member
        case .removeAdmin: access.canChangeRoles && member.role == .admin
        case .remove: access.canRemove(member.role)
        case .ban: access.canBan(member.role)
        }
    }

    private func replaceRow(_ changed: GroupMember) {
        guard let index = members.firstIndex(where: { $0.userId == changed.userId }) else { return }
        members[index] = changed
    }

    /// Takes the row off the roster and, when the backend answered the group, shows its new member count.
    private func dropRow(_ member: GroupMember, updated: SportGroup?) {
        members.removeAll { $0.userId == member.userId }
        let group = updated ?? self.group.updatingMembership(self.group.membership,
                                                             memberCount: self.group.memberCount - 1,
                                                             channelEpoch: self.group.channelEpoch + 1)
        self.group = group
        onChange(group)
    }
}
