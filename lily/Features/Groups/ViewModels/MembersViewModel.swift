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

        /// Removing and banning take a person out of the group and are confirmed first; promotions act at once.
        var isDestructive: Bool { self == .remove || self == .ban }

        /// The question asked before a destructive action; nil for the ones that act at once.
        func confirmation(for member: GroupMember) -> GroupConfirmation? {
            switch self {
            case .remove: .remove(member)
            case .ban: .ban(member)
            case .makeAdmin, .removeAdmin: nil
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
    private let gate: WriteGate
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
        gate = WriteGate(category: .groups,
                         logger: logger,
                         tryAgainDelay: tryAgainDelay,
                         report: { reporter.report($0) })
        self.onChange = onChange
    }

    var access: GroupAccess { GroupAccess(group: group, userID: identity.currentUserID) }

    /// The banned section is for those who can ban.
    var showsBans: Bool { access.canEdit }

    func isSelf(_ member: GroupMember) -> Bool {
        member.userId == identity.currentUserID
    }

    /// The detail's group changed under the roster (a rename, a count, the caller's role): the menus follow it.
    func update(group: SportGroup) {
        guard group.id == self.group.id else { return }
        self.group = group
    }

    /// The actions the caller may take on `member`; empty for the caller's own row, for rows above their reach and
    /// for anyone reading a public roster from outside the group.
    func actions(for member: GroupMember) -> [MemberAction] {
        guard access.isMember, !isSelf(member) else { return [] }
        return MemberAction.allCases.filter { allows($0, on: member) }
    }

    /// The roster, and the banned list when the caller may act on it.
    func load() async {
        guard access.canSeeMembers(in: group) else { return }
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
            dropRow(member)
            adopt(updated)
            logger.info(.groups, "Member \(member.userId) removed from group \(group.id)")
        }
    }

    /// A ban is a role change to `banned`: the row moves from the roster to the banned list. The backend answers the
    /// member, not the group, so the group is read back for its new count and epoch.
    private func ban(_ member: GroupMember) async {
        await act("Ban") {
            let banned = try await repository.setRole(id: group.id, userID: member.userId, .banned)
            dropRow(member)
            bans.insert(banned, at: 0)
            logger.info(.groups, "Member \(member.userId) banned in group \(group.id)")
            await refreshGroup(after: "ban")
        }
    }

    /// One action at a time; the gate repeats a `TRY_AGAIN` once, keeps a dismissed screen quiet and sends a failure
    /// to the popup. Every action is safe to repeat, so a refusal needs no second-guessing: the next load shows the
    /// roster as it is.
    private func act(_ name: String, _ change: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await gate.run("\(name) in group \(group.id)", change)
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

    private func dropRow(_ member: GroupMember) {
        members.removeAll { $0.userId == member.userId }
    }

    /// The group as the backend now has it replaces the roster's copy and reaches the detail, which writes it to Mine.
    private func adopt(_ fresh: SportGroup) {
        group = fresh
        onChange(fresh)
    }

    /// Reads the group back after a write that answered the member alone. A failed read is a warning, never a popup:
    /// the write landed and the row moved; the count catches up on the next Mine reload.
    private func refreshGroup(after name: String) async {
        do {
            adopt(try await repository.group(id: group.id))
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.groups, "Could not refresh group \(group.id) after the \(name): \(error)")
        }
    }
}
