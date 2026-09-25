import Foundation
import Testing
@testable import lily

@MainActor
struct GroupDetailViewModelTests {
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    /// Refusals a join can meet without the group vanishing: expected product states, logged as warnings.
    nonisolated private static let joinRefusals: [AppError] = [
        .groupFull, .bannedFromGroup, .membershipLimitReached, .insufficientRole,
    ]
    /// Failures that leave the outcome unknown: the backend commits before it answers.
    nonisolated private static let unknownOutcomes: [AppError] = [.network, .groupActionFailed]

    private let harness = GroupHarness()

    /// The repository stores `group`, so writes and refetches answer from it until a test changes `result`.
    private func makeViewModel(_ group: SportGroup, context: GroupDetailContext = .standalone) -> GroupDetailViewModel {
        harness.repository.result = .success([group])
        return GroupDetailViewModel(group: group,
                                    context: context,
                                    repository: harness.repository,
                                    identity: harness.identity,
                                    store: harness.store,
                                    reporter: harness.reporter,
                                    recorder: harness.recorder,
                                    logger: harness.logger,
                                    tryAgainDelay: .zero,
                                    now: { Self.now },
                                    onChange: harness.sink.record)
    }

    @Test func accessFollowsTheCallerLive() {
        let viewModel = makeViewModel(.fixture(id: "g"))
        #expect(viewModel.access == .canJoin)

        harness.identity.currentUserID = nil
        #expect(viewModel.access == .guest)
    }

    @Test func openChatShowsForMembersOnlyFromOutsideTheChat() {
        #expect(makeViewModel(.fixture(id: "g", role: .member)).showsOpenChat)
        #expect(!makeViewModel(.fixture(id: "g", role: .member), context: .fromChat).showsOpenChat)
        #expect(!makeViewModel(.fixture(id: "g")).showsOpenChat)
    }

    @Test func recordViewedReportsTheGroupOncePerInstance() {
        let viewModel = makeViewModel(.fixture(id: "g", visibility: .private, role: .member))

        viewModel.recordViewed()
        viewModel.recordViewed()

        #expect(harness.recorder.kinds == [.groupViewed])
        #expect(harness.recorder.interactions.first?.groupId == "g")
        #expect(harness.recorder.interactions.first?.groupVisibility == .private)
    }

    /// The roster's removals and the edit sheet's saves come back through `accept` and travel like the detail's own writes.
    @Test func acceptingASiblingsChangeReplacesTheGroupHereInMineAndBehind() {
        let group = SportGroup.fixture(id: "g", memberCount: 5, role: .owner)
        harness.store.add(group)
        let viewModel = makeViewModel(group)

        viewModel.accept(.fixture(id: "g", name: "Renamed", memberCount: 4, role: .owner))

        #expect(viewModel.group.name == "Renamed" && viewModel.group.memberCount == 4)
        #expect(harness.store.groups.map(\.name) == ["Renamed"])
        #expect(harness.changed.map(\.memberCount) == [4])
        #expect(!viewModel.isGone)
    }

    @Test func joinPutsTheGroupIntoMineAndHandsItOn() async {
        let viewModel = makeViewModel(.fixture(id: "g", memberCount: 5))

        await viewModel.join()

        #expect(viewModel.group.isMember && viewModel.group.memberCount == 6)
        #expect(harness.store.groups.map(\.id) == ["g"])
        #expect(harness.changed.map(\.memberCount) == [6])
        #expect(harness.logs(.info).contains("Joined group g (public)"))
        #expect(harness.changes.version == 1 && !viewModel.isGone)
    }

    @Test func leaveTakesTheGroupOutOfMine() async {
        let group = SportGroup.fixture(id: "g", role: .member)
        harness.store.add(group)
        let viewModel = makeViewModel(group)

        await viewModel.leave()

        #expect(!viewModel.group.isMember && harness.store.groups.isEmpty)
        #expect(harness.changed.count == 1)
        #expect(harness.logs(.info).contains("Left group g"))
    }

    @Test func deleteMarksTheGroupGone() async {
        let group = SportGroup.fixture(id: "g", role: .owner)
        harness.store.add(group)
        let viewModel = makeViewModel(group)

        await viewModel.delete()

        #expect(viewModel.isGone && viewModel.group.isDeleted)
        #expect(harness.store.groups.isEmpty)
        #expect(harness.logs(.info).contains("Group g deleted"))
    }

    /// The view sends a guest to sign in; the view model never lets a guest's tap become a request.
    @Test func aGuestNeverWrites() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.identity.currentUserID = nil

        await viewModel.join()

        #expect(harness.repository.joinedGroupIDs.isEmpty && harness.presentedError == nil)
    }

    @Test func tryAgainIsRepeatedOnce() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.transientErrors = [.tryAgain]

        await viewModel.join()

        #expect(harness.repository.joinedGroupIDs.count == 2)
        #expect(viewModel.group.isMember && harness.presentedError == nil)
        #expect(harness.logs(.info).contains("Join lost a race for group g; retrying once"))
    }

    @Test func aSecondTryAgainIsARefusal() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.transientErrors = [.tryAgain, .tryAgain]

        await viewModel.join()

        #expect(harness.repository.joinedGroupIDs.count == 2)
        #expect(harness.presentedError == .tryAgain)
        #expect(harness.repository.fetchedGroupIDs == ["g"], "the refusal is followed by a refetch")
        #expect(harness.logs(.warning).count == 1)
    }

    /// The popup and the numbers must agree, so the group is refreshed before the refusal is shown; never skipped.
    @Test(arguments: joinRefusals) func aRefusalRefreshesTheGroupAndShowsThePopup(_ error: AppError) async {
        let viewModel = makeViewModel(.fixture(id: "g", memberCount: 5))
        harness.repository.actionError = error
        harness.repository.result = .success([.fixture(id: "g", memberCount: 7)])

        await viewModel.join()

        #expect(viewModel.group.memberCount == 7)
        #expect(harness.presentedError == error)
        #expect(harness.changed.map(\.memberCount) == [7])
        #expect(harness.store.groups.isEmpty, "a group the caller is not in never enters Mine")
        #expect(harness.logs(.warning).count == 1 && harness.logs(.error).isEmpty)
    }

    @Test func aGroupThatVanishedIsGoneAndTheRefusalShown() async {
        let group = SportGroup.fixture(id: "g", role: .member)
        harness.store.add(group)
        let viewModel = makeViewModel(group)
        harness.repository.actionError = AppError.groupNotFound
        harness.repository.result = .success([])

        await viewModel.leave()

        #expect(viewModel.isGone && harness.store.groups.isEmpty)
        #expect(harness.presentedError == .groupNotFound)
    }

    @Test(arguments: unknownOutcomes) func anUnknownOutcomeThatLandedIsNotReported(_ error: AppError) async {
        let viewModel = makeViewModel(.fixture(id: "g", memberCount: 5))
        harness.repository.actionError = error
        harness.repository.result = .success([.fixture(id: "g", memberCount: 6, role: .member)])

        await viewModel.join()

        #expect(viewModel.group.isMember && harness.presentedError == nil)
        #expect(harness.store.groups.map(\.id) == ["g"])
        #expect(harness.logs(.error).count == 1)
        #expect(harness.logs(.info).contains { $0.hasPrefix("Join landed for group g despite") })
    }

    @Test func anUnknownOutcomeThatDidNotLandIsReported() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.actionError = AppError.network

        await viewModel.join()

        #expect(harness.presentedError == .network)
        #expect(harness.repository.fetchedGroupIDs == ["g"])
        #expect(!viewModel.group.isMember && harness.store.groups.isEmpty)
    }

    @Test func aRefetchThatFailsKeepsThePopup() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.actionError = AppError.network
        harness.repository.thrownError = AppError.groupsUnavailable

        await viewModel.join()

        #expect(harness.presentedError == .network)
        #expect(harness.logs(.warning).contains { $0.hasPrefix("Could not refresh group g") })
    }

    /// `NOT_A_MEMBER` on a leave means the caller is already out: what they asked for.
    @Test func notAMemberOnALeaveMeansItLanded() async {
        let group = SportGroup.fixture(id: "g", role: .member)
        harness.store.add(group)
        let viewModel = makeViewModel(group)
        harness.repository.actionError = AppError.notAMember
        harness.repository.result = .success([.fixture(id: "g")])

        await viewModel.leave()

        #expect(harness.presentedError == nil)
        #expect(!viewModel.group.isMember && harness.store.groups.isEmpty)
    }

    /// A private group answers 404 once the caller is out, which after a leave is the intended state.
    @Test func leavingAPrivateGroupThatAnswersNotFoundOnRefetchIsGone() async {
        let group = SportGroup.fixture(id: "g", visibility: .private, role: .member)
        harness.store.add(group)
        let viewModel = makeViewModel(group)
        harness.repository.actionError = AppError.network
        harness.repository.result = .success([])

        await viewModel.leave()

        #expect(viewModel.isGone && harness.store.groups.isEmpty)
        #expect(harness.presentedError == nil)
    }

    @Test func aSecondTapWhileBusyIsDropped() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.holdsRequests = true
        let first = Task { await viewModel.join() }
        await settle(until: { harness.repository.joinedGroupIDs.count == 1 })

        await viewModel.join()
        #expect(harness.repository.joinedGroupIDs.count == 1 && viewModel.isBusy)

        harness.repository.releaseRequests()
        await first.value
        #expect(!viewModel.isBusy && viewModel.group.isMember)
    }

    @Test func cancellationStaysQuiet() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.actionError = CancellationError()

        await viewModel.join()

        #expect(harness.presentedError == nil && harness.logs().isEmpty)
    }

    @Test func termsRequiredRaisesTheTermsSheetWithoutARefetch() async {
        let viewModel = makeViewModel(.fixture(id: "g"))
        harness.repository.actionError = AppError.termsRequired

        await viewModel.join()

        #expect(harness.presentedError == .termsRequired)
        #expect(harness.termsRequiredCount == 1)
        #expect(harness.repository.fetchedGroupIDs.isEmpty)
    }
}
