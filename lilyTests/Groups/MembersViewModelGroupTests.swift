import Foundation
import Testing
@testable import lily

/// How the roster keeps its group truthful: a ban reads the group back instead of counting on the device, a failed
/// read or a failed banned list never costs the rows already shown, and destructive actions are the ones asked first.
@MainActor
struct MembersViewModelGroupTests {
    private let harness = GroupHarness()
    /// The caller (`u-1`) owns the roster's group.
    private let owner = GroupMember.fixture(userId: TestFixtures.user.id, role: .owner)
    private let admin = GroupMember.fixture(userId: "u-2", role: .admin)
    private let member = GroupMember.fixture(userId: "u-3", role: .member)
    private let banned = GroupMember.fixture(userId: "u-9", role: .banned)

    init() {
        harness.repository.members = [owner, admin, member, banned]
    }

    private func makeOwnersViewModel() -> MembersViewModel {
        harness.makeMembersViewModel(group: .fixture(id: "g", memberCount: 3, role: .owner))
    }

    /// The backend answers the banned member alone, so the group is read back rather than its count decremented on the device.
    @Test func aBanRefetchesTheGroup() async {
        let viewModel = makeOwnersViewModel()
        await viewModel.load()
        harness.repository.result = .success([.fixture(id: "g", name: "Renamed", memberCount: 4, role: .owner)])

        await viewModel.perform(.ban, on: member)

        #expect(viewModel.group.name == "Renamed" && viewModel.group.memberCount == 4)
        #expect(harness.changed.map(\.name) == ["Renamed"])
        #expect(harness.repository.fetchedGroupIDs == ["g"])
        #expect(viewModel.bans.first?.userId == "u-3")
    }

    /// The ban landed and the row moved; a read-back that fails is a warning, and the count waits for the next reload.
    @Test func aBanWhoseRefetchFailsStillMovesTheRowAndStaysQuiet() async {
        let viewModel = makeOwnersViewModel()
        await viewModel.load()
        harness.repository.thrownError = AppError.groupsUnavailable

        await viewModel.perform(.ban, on: member)

        #expect(viewModel.members.map(\.userId) == ["u-1", "u-2"])
        #expect(viewModel.bans.first?.userId == "u-3")
        #expect(harness.changed.isEmpty && harness.presentedError == nil)
        #expect(harness.logs(.warning) == ["Could not refresh group g after the ban: groupsUnavailable"])
        #expect(viewModel.group.memberCount == 3, "no arithmetic on the snapshot")
    }

    @Test func aFailedBansLoadKeepsTheRosterAndShowsThePopup() async {
        let viewModel = makeOwnersViewModel()
        harness.repository.bansError = AppError.groupsUnavailable

        await viewModel.load()

        #expect(viewModel.members.count == 3 && viewModel.bans.isEmpty)
        #expect(harness.presentedError == .groupsUnavailable)
        #expect(harness.logs(.error).count == 1)
        #expect(!viewModel.isLoading)
    }

    @Test func removeAndBanAskFirstRoleChangesDoNot() {
        typealias Action = MembersViewModel.MemberAction
        let target = GroupMember.fixture(userId: "u-9")

        #expect(Action.allCases.filter(\.isDestructive) == [.remove, .ban])
        for action in Action.allCases {
            let confirmation = action.confirmation(for: target)
            #expect((confirmation != nil) == action.isDestructive, "\(action)")
            let title = confirmation?.title(groupName: "Kickers")
            #expect(title?.contains(target.displayName) ?? !action.isDestructive, "\(action)")
        }
        #expect(Action.remove.confirmation(for: target) == .remove(target))
        #expect(Action.ban.confirmation(for: target) == .ban(target))
    }
}
