import Foundation
import Testing
@testable import lily

/// The delete flow's state machine (the deletion contract): the advisory summary with the zero-count lines dropped, a
/// confirm that stands the expired-session end down and polls the account read until it lands, the one-time
/// acknowledgment as the only trigger of the account-deleted end (the relocation contract's teardown order), and a
/// refusal before the claim backing the whole flow out.
@MainActor
struct DeleteAccountViewModelTests {
    /// Records the session words in order, so the teardown order is asserted, not assumed.
    @MainActor
    private final class SpyDeletionSession: AccountDeletionSession {
        private(set) var events: [String] = []

        func beginAccountDeletion() { events.append("begin") }
        func cancelAccountDeletion() { events.append("cancel") }
        func endDeletedSession() async { events.append("end") }
    }

    private let session = SpyDeletionSession()
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let sleep = HeldSleep()

    init() {
        errorCenter = ErrorCenter(logger: logger)
    }

    private func makeModel(repository: any MeRepository) -> DeleteAccountViewModel {
        DeleteAccountViewModel(repository: repository,
                               session: session,
                               errorCenter: errorCenter,
                               logger: logger) { [sleep] in try await sleep.sleep(for: $0) }
    }

    private func makeMockBacked() -> DeleteAccountViewModel {
        makeModel(repository: MockMeRepository(identity: FakeIdentityProvider(currentUserID: "u-1"), logger: logger))
    }

    @Test func theSummaryDropsZeroCountLinesAndNothingElse() {
        let plan = DeletionPlan(groupsTransferring: 2,
                                groupsDeleted: 1,
                                eventsCancelled: 1,
                                entriesWithdrawn: 3,
                                tournamentsCancelled: 0)
        let lines = DeleteAccountViewModel.lines(for: plan)
        #expect(lines == [AppBranding.DeleteAccount.groupsTransferring(2),
                          AppBranding.DeleteAccount.groupsDeleted(1),
                          AppBranding.DeleteAccount.eventsCancelled(1),
                          AppBranding.DeleteAccount.entriesWithdrawn(3)],
                "one line per non-zero count, in the plan's order, the zero dropped")
        #expect(DeleteAccountViewModel.lines(for: nil).isEmpty)
        let empty = DeletionPlan(groupsTransferring: 0,
                                 groupsDeleted: 0,
                                 eventsCancelled: 0,
                                 entriesWithdrawn: 0,
                                 tournamentsCancelled: 0)
        #expect(DeleteAccountViewModel.lines(for: empty).isEmpty,
                "an account owning nothing keeps only the view's always-true messages sentence")
    }

    @Test func prepareLoadsTheAdvisoryPlanOnce() async {
        let viewModel = makeMockBacked()

        await viewModel.prepare()

        #expect(viewModel.plan?.groupsTransferring == 2 && !viewModel.isLoadingPlan)
        #expect(viewModel.summaryLines.count == 4, "the mock plan's zero count is dropped")
    }

    @Test func aFailedPlanLoadReportsThePopupAndBlocksNothing() async {
        let repository = FakeMeRepository()
        repository.deletionPlanResult = .failure(.deletionPlanUnavailable)
        let viewModel = makeModel(repository: repository)

        await viewModel.prepare()

        #expect(errorCenter.current?.error == .deletionPlanUnavailable)
        #expect(viewModel.plan == nil && viewModel.summaryLines.isEmpty)
        #expect(!viewModel.isLocked, "a failed preview never stands between the caller and erasure")
        #expect(logger.messages(in: .auth, at: .warning).contains { $0.contains("Deletion plan load failed") })
    }

    /// The account-deleted teardown re-instantiates the sheet's content, whose fresh `.task` re-runs `prepare()`
    /// against the dead session: its landed answer must never raise the "Session expired" popup over the landing.
    @Test func aLandedPlanLoadAfterTheTeardownReportsNothing() async {
        let repository = FakeMeRepository()
        repository.deletionPlanResult = .failure(.sessionExpired)
        let viewModel = makeModel(repository: repository)

        await viewModel.prepare()

        #expect(errorCenter.current == nil, "the client end path suppresses the expired-session popup")
        #expect(viewModel.plan == nil && !viewModel.isLocked)
        #expect(logger.messages(in: .auth, at: .debug).contains { $0.contains("Deletion plan load found the session ended") })
        #expect(!logger.messages(in: .auth, at: .warning).contains { $0.contains("Deletion plan load failed") },
                "a landed read is not the preview failing")
    }

    @Test func confirmLocksPollsUntilLandedAndWaitsForTheAcknowledgment() async {
        let viewModel = makeMockBacked()
        let flow = Task { await viewModel.confirmDeletion() }

        await settle(until: { sleep.held.count == 1 })
        #expect(viewModel.isDeleting && viewModel.isLocked, "the claim is out: the sheet is locked")
        #expect(session.events == ["begin"], "nothing ends while the poll runs")

        sleep.release()
        // The mock's first poll still answers (the job runs); the second is the tombstone's 401.
        await settle(until: { sleep.held.count == 1 })
        #expect(!viewModel.isDeleted)
        sleep.release()
        await flow.value

        #expect(viewModel.isDeleted && !viewModel.isDeleting && viewModel.isLocked)
        #expect(session.events == ["begin"], "only the acknowledge tap may end the session")
        #expect(errorCenter.current == nil)
        #expect(logger.messages(in: .auth).contains { $0.contains("Account deletion landed after 2 polls") })

        await viewModel.acknowledge()
        #expect(session.events == ["begin", "end"], "the pinned teardown order: the end comes from the tap alone")
    }

    @Test func acknowledgeBeforeTheDeletionLandedDoesNothing() async {
        let viewModel = makeMockBacked()

        await viewModel.acknowledge()

        #expect(session.events.isEmpty)
    }

    @Test func aRefusalBeforeTheClaimBacksTheFlowOut() async {
        let repository = FakeMeRepository()
        repository.deleteError = .accountDeletionFailed
        let viewModel = makeModel(repository: repository)

        await viewModel.confirmDeletion()

        #expect(session.events == ["begin", "cancel"], "the expired-session end acts again")
        #expect(!viewModel.isDeleting && !viewModel.isDeleted, "the sheet unlocks for a repeat")
        #expect(errorCenter.current?.error == .accountDeletionFailed)
        #expect(logger.messages(in: .auth, at: .error).contains { $0.contains("Account deletion request failed") })
    }

    @Test func aReplayThatFindsTheJobCompletedLandsWithoutAPoll() async {
        let repository = FakeMeRepository()
        repository.deleteError = .sessionExpired
        let viewModel = makeModel(repository: repository)

        await viewModel.confirmDeletion()

        #expect(viewModel.isDeleted, "the tombstone's 401 is the deletion landing, never a failure")
        #expect(session.events == ["begin"])
        #expect(errorCenter.current == nil)
        #expect(logger.messages(in: .auth).contains { $0.contains("Account deletion landed after 0 polls") })
    }

    @Test func anUnsettledPollAnswerKeepsPolling() async {
        let repository = FakeMeRepository()
        repository.meResult = .failure(.network)
        let viewModel = makeModel(repository: repository)
        let flow = Task { await viewModel.confirmDeletion() }

        await settle(until: { sleep.held.count == 1 })
        sleep.release()
        await settle(until: { sleep.held.count == 1 })
        #expect(viewModel.isDeleting && !viewModel.isDeleted, "a network failure settles on a later read")

        repository.meResult = .failure(.sessionExpired)
        sleep.release()
        await flow.value
        #expect(viewModel.isDeleted)
    }

    @Test func aSecondConfirmWhileLockedIsTurnedAway() async {
        let repository = FakeMeRepository()
        let viewModel = makeModel(repository: repository)
        let flow = Task { await viewModel.confirmDeletion() }
        await settle(until: { sleep.held.count == 1 })

        await viewModel.confirmDeletion()

        #expect(repository.deleteCallCount == 1 && session.events == ["begin"])
        repository.meResult = .failure(.sessionExpired)
        sleep.release()
        await flow.value
        #expect(viewModel.isDeleted)
    }
}
