import Foundation
import Testing
@testable import lily

/// What a write's answer, failure or refetch does for whom; `GroupDetailViewModelTests` is near the type-body limit.
@MainActor
struct GroupDetailCallerTests {
    private let snapshots = InMemoryListSnapshotStore()
    private let harness: GroupHarness

    init() {
        harness = GroupHarness(snapshots: snapshots)
    }

    /// A sign-out and sign-in while the join is out: the answer is the previous caller's group and must not enter the
    /// next caller's Mine, its snapshot or the change count.
    @Test func aJoinAnswerForAPreviousCallerIsDropped() async {
        let viewModel = harness.makeGroupDetailViewModel(.fixture(id: "g"))
        harness.repository.holdsRequests = true
        let version = harness.changes.version

        let join = Task { await viewModel.join() }
        await settle(until: { harness.repository.joinedGroupIDs.count == 1 })
        harness.identity.currentUserID = "someone-else"
        harness.repository.releaseRequests()
        await join.value

        #expect(harness.store.groups.isEmpty && snapshots.saveCount == 0)
        #expect(harness.changes.version == version && !viewModel.isBusy)
        #expect(!viewModel.group.isMember && harness.presentedError == nil)
        #expect(harness.logger.count(in: .cache, at: .debug, mentioning: "Join answer for a previous caller dropped") == 1)
    }

    /// Nor is a failure the previous caller's request met refetched for, logged against or shown to whoever is there now.
    @Test func aFailureForAPreviousCallerIsNeitherRefetchedNorShown() async {
        let viewModel = harness.makeGroupDetailViewModel(.fixture(id: "g"))
        harness.repository.actionError = AppError.network
        harness.repository.holdsRequests = true

        let join = Task { await viewModel.join() }
        await settle(until: { harness.repository.joinedGroupIDs.count == 1 })
        harness.identity.currentUserID = nil
        harness.store.sessionDidEnd()
        harness.repository.releaseRequests()
        await join.value

        #expect(harness.repository.fetchedGroupIDs.isEmpty && harness.presentedError == nil)
        #expect(harness.logs(.error).isEmpty && harness.store.groups.isEmpty)
        #expect(harness.logger.count(in: .cache, at: .debug, mentioning: "Join failure for a previous caller dropped") == 1)
    }

    /// The caller changes while the refetch after an unknown outcome is out: the fresh group (which would show the join
    /// landed) is the previous caller's, so it writes nothing, and the failure is shown to nobody.
    @Test func aRefetchAnswerForAPreviousCallerIsDropped() async {
        let viewModel = harness.makeGroupDetailViewModel(.fixture(id: "g"))
        harness.repository.result = .success([.fixture(id: "g", role: .member)])
        harness.repository.actionError = AppError.network
        harness.repository.holdsFetches = true

        let join = Task { await viewModel.join() }
        await settle(until: { harness.repository.fetchedGroupIDs.count == 1 })
        harness.identity.currentUserID = "someone-else"
        harness.repository.releaseFetches()
        await join.value

        #expect(harness.store.groups.isEmpty && !viewModel.isGone && !viewModel.group.isMember)
        #expect(harness.presentedError == nil && !viewModel.isBusy)
        #expect(!harness.logs(.info).contains { $0.hasPrefix("Refreshed group") })
        #expect(harness.logger.count(in: .cache, at: .debug, mentioning: "Join refetch for a previous caller dropped") == 1)
    }
}
