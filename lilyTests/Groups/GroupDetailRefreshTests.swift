import Foundation
import Testing
@testable import lily

/// The open detail follows Mine, the roster follows the detail, and a delete whose outcome is unknown is settled by a
/// refetch, like a join or a leave.
@MainActor
struct GroupDetailRefreshTests {
    private let harness = GroupHarness()
    private let member = GroupMember.fixture(userId: "u-3", role: .member)

    @Test func theDetailFollowsAMineReload() async {
        let group = SportGroup.fixture(id: "g", role: .member)
        harness.store.add(group)
        let viewModel = harness.makeGroupDetailViewModel(group)
        harness.repository.result = .success([.fixture(id: "g", name: "Renamed", memberCount: 7, role: .member)])

        await harness.store.reload()
        viewModel.refreshFromStore()

        #expect(viewModel.group.name == "Renamed" && viewModel.group.memberCount == 7)
    }

    /// A `group_updated` broadcast carries no membership; the detail takes Mine's merged copy and stays a member's.
    @Test func aLiveUpdateInMineReachesTheDetail() {
        let group = SportGroup.fixture(id: "g", role: .member)
        harness.store.add(group)
        let viewModel = harness.makeGroupDetailViewModel(group)

        harness.store.apply(.fixture(id: "g", name: "Renamed", memberCount: 7))
        viewModel.refreshFromStore()

        #expect(viewModel.group.name == "Renamed" && viewModel.group.memberCount == 7)
        #expect(viewModel.group.isMember)
    }

    /// A non-member's public group is not Mine's to show: the store moving says nothing about it.
    @Test func aGroupNotInMineKeepsItsCopy() {
        let group = SportGroup.fixture(id: "g")
        let viewModel = harness.makeGroupDetailViewModel(group)

        harness.store.add(.fixture(id: "other", role: .member))
        viewModel.refreshFromStore()

        #expect(viewModel.group == group)
    }

    /// Discover answers fresher than Mine's copy; the store has not moved since the push, so the pushed group stays.
    @Test func aFresherPushedGroupIsNotReplacedOnAppearance() {
        harness.store.add(.fixture(id: "g", name: "Old", role: .member))
        let viewModel = harness.makeGroupDetailViewModel(.fixture(id: "g", name: "New", role: .member))

        viewModel.refreshFromStore()

        #expect(viewModel.group.name == "New")
    }

    @Test func aGoneDetailTakesNothingFromMine() async {
        let group = SportGroup.fixture(id: "g", role: .owner)
        harness.store.add(group)
        let viewModel = harness.makeGroupDetailViewModel(group)
        await viewModel.delete()

        harness.store.add(group)
        viewModel.refreshFromStore()

        #expect(viewModel.isGone && viewModel.group.isDeleted)
    }

    @Test func signingInOnTheDetailShowsTheRoster() {
        let viewModel = harness.makeGroupDetailViewModel(.fixture(id: "g"))

        harness.identity.currentUserID = nil
        #expect(!viewModel.showsRoster)

        harness.identity.currentUserID = TestFixtures.user.id
        #expect(viewModel.showsRoster)
    }

    @Test func aPrivateGroupsRosterStaysMembersOnly() {
        #expect(!harness.makeGroupDetailViewModel(.fixture(id: "g", visibility: .private)).showsRoster)
        #expect(harness.makeGroupDetailViewModel(.fixture(id: "g", visibility: .private, role: .member)).showsRoster)
    }

    /// The backend commits a delete before it answers: a 404 on the refetch means it landed, so nothing is reported.
    @Test func aDeleteWithAnUnknownOutcomeIsRefetched() async {
        let group = SportGroup.fixture(id: "g", role: .owner)
        harness.store.add(group)
        let viewModel = harness.makeGroupDetailViewModel(group)
        harness.repository.actionError = AppError.network
        harness.repository.result = .success([])

        await viewModel.delete()

        #expect(viewModel.isGone && harness.store.groups.isEmpty)
        #expect(harness.presentedError == nil)
        #expect(harness.logs(.info).contains("Delete landed for group g despite network; nothing to report"))
    }

    @Test func aDeleteWhoseRefetchAnswersTheDeletedGroupIsGone() async {
        let group = SportGroup.fixture(id: "g", role: .owner)
        harness.store.add(group)
        let viewModel = harness.makeGroupDetailViewModel(group)
        harness.repository.actionError = AppError.network
        harness.repository.result = .success([group.markingDeleted(at: Date(timeIntervalSince1970: 1_800_000_060))])

        await viewModel.delete()

        #expect(viewModel.isGone && viewModel.group.isDeleted)
        #expect(harness.store.groups.isEmpty && harness.presentedError == nil)
    }

    /// A rename, a count or the caller's role reaches the roster, so a menu never acts on a stale snapshot.
    @Test func updateGroupMovesTheRosterToTheDetailsGroup() {
        let viewModel = harness.makeMembersViewModel(group: .fixture(id: "g", role: .owner))
        #expect(!viewModel.actions(for: member).isEmpty)

        viewModel.update(group: .fixture(id: "g", name: "Renamed", memberCount: 9, role: .owner))
        #expect(viewModel.group.name == "Renamed" && viewModel.group.memberCount == 9)

        viewModel.update(group: .fixture(id: "g", role: .member))
        #expect(viewModel.actions(for: member).isEmpty, "the menus follow the caller's role")
    }

    @Test func updateGroupIgnoresAnotherGroup() {
        let group = SportGroup.fixture(id: "g", role: .owner)
        let viewModel = harness.makeMembersViewModel(group: group)

        viewModel.update(group: .fixture(id: "other", name: "Renamed", role: .member))

        #expect(viewModel.group == group)
    }
}
