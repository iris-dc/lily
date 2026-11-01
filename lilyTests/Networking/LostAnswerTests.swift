import Testing
@testable import lily

/// The backend's side of the read-back: what it answers, how often it was asked, what was applied.
@MainActor
private final class Backend {
    var fresh: Result<Int, any Error> = .success(1)
    var refetches = 0
    var applied: [Int] = []
}

/// One rule for every write whose answer was lost: read back, show the fresh state, and only an intent the fresh state
/// shows counts as landed.
@MainActor
struct LostAnswerTests {
    private let logger = SpyLogger()
    private let backend = Backend()

    @Test func aRefusalIsNotReadBack() async {
        let settled = await settle(despite: AppError.tournamentFull) { _ in true }

        #expect(settled == .unresolved && !settled.isLanded)
        #expect(backend.refetches == 0 && backend.applied.isEmpty)
        #expect(logger.messages(in: .tournaments).isEmpty)
    }

    @Test func aLostAnswerWhoseReadBackShowsTheIntentIsLanded() async {
        let settled = await settle(despite: AppError.network) { $0 == 1 }

        #expect(settled == .landed && settled.isLanded)
        #expect(backend.refetches == 1 && backend.applied == [1])
        #expect(logger.count(in: .tournaments, at: .warning) == 1)
        #expect(logger.hasLine(in: .tournaments, at: .warning, mentioning: "Join t", "outcome unknown", "reading back"))
        #expect(logger.count(in: .tournaments, at: .info) == 1)
        #expect(logger.hasLine(in: .tournaments, at: .info, mentioning: "Join t", "landed", "despite", "nothing to report"))
    }

    @Test func aReadBackThatDoesNotShowTheIntentIsAppliedAndNotLanded() async {
        let settled = await settle(despite: AppError.network) { $0 == 2 }

        #expect(settled == .didNotLand)
        #expect(backend.applied == [1], "the fresh state is shown before the popup")
        #expect(logger.messages(in: .tournaments, at: .info).isEmpty)
    }

    @Test func aFailedReadBackIsUnresolvedWithAWarning() async {
        backend.fresh = .failure(AppError.tournamentsUnavailable)

        let settled = await settle(despite: AppError.network) { _ in true }

        #expect(settled == .unresolved && backend.applied.isEmpty)
        #expect(logger.count(in: .tournaments, at: .warning) == 2, "the read-back and its failure")
        #expect(logger.hasLine(in: .tournaments, at: .warning, mentioning: "Could not read back", "Join t"))
    }

    @Test func aReadBackThatCannotTellIsUnresolved() async {
        let settled = await settle(despite: AppError.network) { _ in nil }

        #expect(settled == .unresolved && backend.applied == [1])
    }

    /// The backend's word that nothing changed: the screen is refreshed, the failure stands.
    @Test func aRefusalWorthAnotherLookIsAppliedButNeverLanded() async {
        let settled = await settle(despite: AppError.tournamentFull,
                                   worthAnotherLook: { $0 == .tournamentFull },
                                   intent: { _ in true })

        #expect(settled == .didNotLand && backend.applied == [1])
        #expect(logger.count(in: .tournaments, at: .info) == 1)
        #expect(logger.hasLine(in: .tournaments, at: .info, mentioning: "Reading back", "\(AppError.tournamentFull)", "Join t"))
        #expect(logger.messages(in: .tournaments, at: .warning).isEmpty)
    }

    @Test func aCancelledReadBackLogsNoWarning() async {
        backend.fresh = .failure(CancellationError())

        let settled = await settle(despite: AppError.network) { _ in true }

        #expect(settled == .unresolved)
        #expect(logger.count(in: .tournaments, at: .warning) == 1, "only the read-back line")
        #expect(!logger.hasLine(in: .tournaments, mentioning: "Could not read back"))
    }

    @Test func anErrorThatIsNoAppErrorIsUnresolved() async {
        let settled = await settle(despite: CancellationError()) { _ in true }

        #expect(settled == .unresolved && backend.refetches == 0)
    }

    /// The sheet dismissed or the session ended while the read-back ran: the fresh state is nobody's to apply and no
    /// verdict reaches the popup.
    @Test func aCallerCancelledDuringTheReadBackGetsNoStateAndNoVerdict() async {
        let settled = await Task { [self] in
            await settle(despite: AppError.network,
                         beforeAnswering: { withUnsafeCurrentTask { $0?.cancel() } },
                         intent: { _ in true })
        }.value

        #expect(settled == .unresolved && backend.refetches == 1 && backend.applied.isEmpty)
        #expect(logger.count(in: .tournaments, at: .warning) == 1, "only the read-back line")
        #expect(logger.messages(in: .tournaments, at: .info).isEmpty, "nothing landed")
    }

    private func settle(despite error: any Error,
                        worthAnotherLook: @escaping (AppError) -> Bool = { _ in false },
                        beforeAnswering: @escaping () -> Void = {},
                        intent: (Int) -> Bool?) async -> LostAnswer<Int>.Settlement {
        let readBack = LostAnswer<Int>(category: .tournaments,
                                       logger: logger,
                                       leavesOutcomeUnknown: { $0 == .network || $0 == .tournamentActionFailed },
                                       isWorthAnotherLook: worthAnotherLook,
                                       refetch: { [backend] in
                                           backend.refetches += 1
                                           beforeAnswering()
                                           return try backend.fresh.get()
                                       },
                                       apply: { [backend] in backend.applied.append($0) })
        return await readBack.settle("Join t", despite: error, intent: intent)
    }
}
