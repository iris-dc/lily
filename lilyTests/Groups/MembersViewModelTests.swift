import Foundation
import Testing
@testable import lily

@MainActor
struct MembersViewModelTests {
    private let harness = GroupHarness()
    /// The caller (`u-1`) owns the roster's group unless a test says otherwise.
    private let owner = GroupMember.fixture(userId: TestFixtures.user.id, role: .owner)
    private let admin = GroupMember.fixture(userId: "u-2", role: .admin)
    private let member = GroupMember.fixture(userId: "u-3", role: .member)
    private let banned = GroupMember.fixture(userId: "u-9", role: .banned)

    init() {
        harness.repository.members = [owner, admin, member, banned]
    }

    private func makeViewModel(role: MemberRole?) -> MembersViewModel {
        makeViewModel(group: SportGroup.fixture(id: "g", memberCount: 3, role: role))
    }

    private func makeViewModel(group: SportGroup) -> MembersViewModel {
        harness.repository.result = .success([group])
        return MembersViewModel(group: group,
                                repository: harness.repository,
                                identity: harness.identity,
                                reporter: harness.reporter,
                                logger: harness.logger,
                                tryAgainDelay: .zero,
                                onChange: harness.sink.record)
    }

    /// The two people of a conversation see each other on its roster and can do nothing to one another there.
    @Test func aConversationsRosterOffersNoActions() async {
        let other = admin.withRole(.member)
        harness.repository.members = [owner.withRole(.member), other]
        let viewModel = makeViewModel(group: .conversationFixture())

        await viewModel.load()

        #expect(viewModel.members.count == 2 && !viewModel.showsBans && viewModel.bans.isEmpty)
        #expect(viewModel.actions(for: other).isEmpty)
    }

    @Test func ownersLoadTheRosterAndTheBans() async {
        let viewModel = makeViewModel(role: .owner)

        await viewModel.load()

        #expect(viewModel.members.map(\.userId) == ["u-1", "u-2", "u-3"])
        #expect(viewModel.bans.map(\.userId) == ["u-9"])
        #expect(viewModel.showsBans && !viewModel.isLoading)
    }

    @Test func membersLoadTheRosterOnly() async {
        let viewModel = makeViewModel(role: .member)

        await viewModel.load()

        #expect(viewModel.members.count == 3)
        #expect(viewModel.bans.isEmpty && !viewModel.showsBans)
    }

    /// The fixture group is public: an outsider reads its roster, with no actions on any row and no banned list.
    @Test func outsidersReadAPublicRosterWithoutActions() async {
        let viewModel = makeViewModel(role: nil)

        await viewModel.load()

        #expect(viewModel.members.count == 3 && viewModel.bans.isEmpty && !viewModel.showsBans)
        #expect(viewModel.members.allSatisfy { viewModel.actions(for: $0).isEmpty })
    }

    @Test func outsidersOfAPrivateGroupLoadNothing() async {
        let group = SportGroup.fixture(id: "g", visibility: .private, memberCount: 3)
        harness.repository.result = .success([group])
        let viewModel = MembersViewModel(group: group,
                                         repository: harness.repository,
                                         identity: harness.identity,
                                         reporter: harness.reporter,
                                         logger: harness.logger,
                                         tryAgainDelay: .zero,
                                         onChange: harness.sink.record)

        await viewModel.load()

        #expect(viewModel.members.isEmpty && viewModel.bans.isEmpty)
    }

    /// Leaving is the detail's action; the backend refuses a self-target anyway.
    @Test func theCallersOwnRowIsNeverOffered() {
        #expect(makeViewModel(role: .owner).actions(for: owner).isEmpty)
        #expect(makeViewModel(role: .admin).actions(for: owner.withRole(.admin)).isEmpty)
        #expect(makeViewModel(role: .owner).isSelf(owner))
    }

    @Test func ownersActOnAdminsAndMembers() {
        let viewModel = makeViewModel(role: .owner)

        #expect(viewModel.actions(for: admin) == [.removeAdmin, .remove, .ban])
        #expect(viewModel.actions(for: member) == [.makeAdmin, .remove, .ban])
    }

    @Test func adminsActOnMembersOnly() {
        let viewModel = makeViewModel(role: .admin)

        #expect(viewModel.actions(for: admin).isEmpty)
        #expect(viewModel.actions(for: member) == [.remove, .ban])
        #expect(makeViewModel(role: .member).actions(for: member).isEmpty)
    }

    @Test func removeDropsTheRowAndHandsTheGroupOn() async {
        let viewModel = makeViewModel(role: .owner)
        await viewModel.load()

        await viewModel.perform(.remove, on: member)

        #expect(viewModel.members.map(\.userId) == ["u-1", "u-2"])
        #expect(harness.repository.removals.map(\.userID) == ["u-3"])
        #expect(viewModel.group.memberCount == 2 && harness.changed.map(\.memberCount) == [2])
        #expect(harness.logs(.info).contains("Member u-3 removed from group g"))
    }

    @Test func tryAgainIsRepeatedOnce() async {
        let viewModel = makeViewModel(role: .owner)
        await viewModel.load()
        harness.repository.transientErrors = [.tryAgain]

        await viewModel.perform(.remove, on: member)

        #expect(viewModel.members.map(\.userId) == ["u-1", "u-2"] && harness.presentedError == nil)
        #expect(harness.logs(.info).contains("Remove lost a race in group g; retrying once"))
    }

    @Test func banMovesTheRowToTheBannedList() async {
        let viewModel = makeViewModel(role: .owner)
        await viewModel.load()

        await viewModel.perform(.ban, on: member)

        #expect(viewModel.members.map(\.userId) == ["u-1", "u-2"])
        #expect(viewModel.bans.map(\.userId) == ["u-3", "u-9"])
        #expect(harness.repository.roleChanges == [FakeGroupRepository.RoleChange(id: "g", userID: "u-3", role: .banned)])
        #expect(viewModel.group.memberCount == 2 && viewModel.group.channelEpoch == 2)
        #expect(harness.changed.count == 1)
    }

    @Test func roleChangesUpdateTheRowInPlace() async {
        let viewModel = makeViewModel(role: .owner)
        await viewModel.load()

        await viewModel.perform(.makeAdmin, on: member)
        await viewModel.perform(.removeAdmin, on: admin)

        #expect(viewModel.members.map(\.role) == [.owner, .member, .admin])
        #expect(harness.repository.roleChanges.map(\.role) == [.admin, .member])
        #expect(harness.changed.isEmpty, "the group itself did not change")
    }

    @Test func unbanTakesTheRowOffTheBannedList() async {
        let viewModel = makeViewModel(role: .admin)
        await viewModel.load()

        await viewModel.unban(banned)

        #expect(viewModel.bans.isEmpty)
        #expect(harness.repository.unbans.map(\.userID) == ["u-9"])
        #expect(harness.logs(.info).contains("Member u-9 unbanned in group g"))
    }

    @Test func anActionOutsideTheCallersReachIsIgnored() async {
        let viewModel = makeViewModel(role: .admin)

        await viewModel.perform(.remove, on: admin)
        await viewModel.perform(.makeAdmin, on: member)

        #expect(harness.repository.removals.isEmpty && harness.repository.roleChanges.isEmpty)
    }

    @Test func aFailureReachesThePopupAndKeepsTheRoster() async {
        let viewModel = makeViewModel(role: .owner)
        await viewModel.load()
        harness.repository.actionError = AppError.insufficientRole

        await viewModel.perform(.remove, on: member)

        #expect(viewModel.members.count == 3)
        #expect(harness.presentedError == .insufficientRole)
        #expect(harness.logs(.error).count == 1)
    }

    @Test func aFailedLoadReachesThePopup() async {
        let viewModel = makeViewModel(role: .owner)
        harness.repository.actionError = AppError.groupsUnavailable

        await viewModel.load()

        #expect(viewModel.members.isEmpty && harness.presentedError == .groupsUnavailable)
    }
}
