import Testing
@testable import lily

/// The thing a form creates: ours unless a test puts someone else's under the id.
private struct Thing: Identifiable, Equatable {
    let id: String
    var mine = true
}

/// The backend's side of the check and what reached the popup.
@MainActor
private final class Box {
    var lookup: Result<Thing, any Error> = .failure(AppError.eventNotFound)
    var lookups = 0
    var reported: [AppError] = []
    /// What the update after a reused id answers, in order; empty answers `Thing(id: "t-1")`.
    var updates: [Result<Thing, any Error>] = []
    var updateCount = 0

    func update() throws -> Thing {
        updateCount += 1
        guard !updates.isEmpty else { return Thing(id: "t-1") }
        return try updates.removeFirst().get()
    }
}

@MainActor
struct CreateFlowTests {
    private let logger = SpyLogger()
    private let box = Box()

    @Test func aSendThatAnswersIsTheOutcomeAndIsLogged() async {
        let created = await submit { Thing(id: "t-1") }

        #expect(created == Thing(id: "t-1"))
        #expect(logger.count(in: .events, at: .info) == 1)
        #expect(logger.hasLine(in: .events, at: .info, mentioning: "t-1", "two spots"))
        #expect(box.lookups == 0 && box.reported.isEmpty)
    }

    @Test func anUnknownOutcomeIsLookedUpAndOursCountsAsLanded() async {
        box.lookup = .success(Thing(id: "t-1"))

        let created = await submit { throw AppError.network }

        #expect(created == Thing(id: "t-1"))
        #expect(logger.count(in: .events, at: .error) == 1)
        #expect(logger.hasLine(in: .events, at: .error, mentioning: "c-1", "\(AppError.network)"))
        #expect(logger.count(in: .events, at: .info) == 1)
        #expect(logger.hasLine(in: .events, at: .info, mentioning: "landed", "t-1"))
        #expect(box.reported.isEmpty)
    }

    @Test func someoneElsesUnderTheIdKeepsTheFailure() async {
        box.lookup = .success(Thing(id: "t-1", mine: false))

        let created = await submit { throw AppError.network }

        #expect(created == nil)
        #expect(box.reported == [.network])
    }

    @Test func notFoundIsTheChecksAnswerAtDebug() async {
        box.lookup = .failure(AppError.eventNotFound)

        let created = await submit { throw AppError.network }

        #expect(created == nil)
        #expect(box.reported == [.network])
        #expect(logger.count(in: .events, at: .debug) == 1)
        #expect(logger.hasLine(in: .events, at: .debug, mentioning: "c-1", "did not land"))
        #expect(logger.messages(in: .events, at: .warning).isEmpty)
    }

    @Test func aFailedLookupIsAWarning() async {
        box.lookup = .failure(AppError.eventsUnavailable)

        let created = await submit { throw AppError.network }

        #expect(created == nil)
        #expect(box.reported == [.network])
        #expect(logger.count(in: .events, at: .warning) == 1)
        #expect(logger.hasLine(in: .events, at: .warning, mentioning: "c-1", "landed", "\(AppError.network)"))
    }

    @Test func aRefusalWithCopyIsReportedWithoutALookup() async {
        let created = await submit { throw AppError.contentRejected }

        #expect(created == nil)
        #expect(box.lookups == 0)
        #expect(box.reported == [.contentRejected])
        #expect(logger.messages(in: .events, at: .error).count == 1)
    }

    @Test func cancellationStaysQuiet() async {
        let created = await submit { throw CancellationError() }

        #expect(created == nil)
        #expect(logger.messages(in: .events).isEmpty && box.reported.isEmpty)
    }

    @Test func aCancelledLookupLogsNoWarningAndStillReports() async {
        box.lookup = .failure(CancellationError())

        let created = await submit { throw AppError.network }

        #expect(created == nil)
        #expect(logger.messages(in: .events, at: .warning).isEmpty)
        #expect(box.reported == [.network])
    }

    /// A create is a write like any other: one `TRY_AGAIN` is repeated under the same client id, a replay on the backend.
    @Test func aLostRaceIsRepeatedOnceAndTheSecondAnswerIsTheOutcome() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .success(1)])

        let created = await submit { try Thing(id: "t-\(script.next())") }

        #expect(created == Thing(id: "t-1") && script.attempts == 2)
        #expect(logger.count(in: .events, at: .info, mentioning: "Create thing c-1", "lost a race") == 1)
        #expect(box.lookups == 0 && box.reported.isEmpty)
    }

    @Test func aSecondLostRaceIsReportedWithoutALookup() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .failure(AppError.tryAgain)])

        let created = await submit { try Thing(id: "t-\(script.next())") }

        #expect(created == nil && script.attempts == 2)
        #expect(box.reported == [.tryAgain] && box.lookups == 0)
    }

    @Test func theRepeatWaitsForThePause() async {
        let sleep = HeldSleep()
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .success(1)])
        let flow = makeFlow(tryAgainDelay: .milliseconds(400), sleep: { [sleep] in try await sleep.sleep(for: $0) })

        let create = Task {
            await flow.submit(clientID: "c-1",
                              describing: { _ in "" },
                              send: { try Thing(id: "t-\(script.next())") },
                              update: { Thing(id: "u") })
        }
        await settle(until: { sleep.held == [.milliseconds(400)] })
        #expect(script.attempts == 1, "the second attempt waits for the pause")

        sleep.release()
        let created = await create.value
        #expect(created == Thing(id: "t-1") && script.attempts == 2)
    }

    /// Our earlier create landed with other details and its answer was lost: the latest details go onto that item.
    @Test func anIdReusedRefusalSendsTheDraftAsAnUpdateAndItsAnswerIsTheOutcome() async {
        box.updates = [.success(Thing(id: "t-1"))]

        let created = await submit { throw AppError.createIdReused }

        #expect(created == Thing(id: "t-1"))
        #expect(box.updateCount == 1 && box.lookups == 0 && box.reported.isEmpty)
        #expect(logger.count(in: .events, at: .warning) == 1)
        #expect(logger.hasLine(in: .events, at: .warning, mentioning: "c-1", "repeated with other details", "updating"))
        #expect(logger.count(in: .events, at: .info) == 1)
        #expect(logger.hasLine(in: .events, at: .info, mentioning: "Thing t-1", "updated with the latest details"))
        #expect(logger.messages(in: .events, at: .error).isEmpty)
    }

    @Test func anUpdateAfterAReusedIdThatFailsIsReportedWithoutALookup() async {
        box.updates = [.failure(AppError.eventUpdateFailed)]

        let created = await submit { throw AppError.createIdReused }

        #expect(created == nil)
        #expect(box.reported == [.eventUpdateFailed] && box.lookups == 0)
        #expect(logger.count(in: .events, at: .error) == 1)
        #expect(logger.hasLine(in: .events, at: .error, mentioning: "Update after a reused id failed", "c-1", "UpdateFailed"))
    }

    @Test func anUpdateAfterAReusedIdRepeatsOneTryAgain() async {
        box.updates = [.failure(AppError.tryAgain), .success(Thing(id: "t-1"))]

        let created = await submit { throw AppError.createIdReused }

        #expect(created == Thing(id: "t-1") && box.updateCount == 2)
        #expect(logger.count(in: .events, at: .info, mentioning: "Update thing c-1", "lost a race") == 1)
        #expect(box.reported.isEmpty)
    }

    @Test func aCancelledUpdateAfterAReusedIdStaysQuiet() async {
        box.updates = [.failure(CancellationError())]

        let created = await submit { throw AppError.createIdReused }

        #expect(created == nil && box.reported.isEmpty)
        #expect(logger.messages(in: .events, at: .error).isEmpty)
    }

    /// The flow an event form would build, over the box's lookup, with no pause before a repeat unless a test holds one.
    private func makeFlow(tryAgainDelay: Duration = .zero, sleep: @escaping Sleep = systemSleep) -> CreateFlow<Thing> {
        CreateFlow(noun: "thing",
                   category: .events,
                   logger: logger,
                   tryAgainDelay: tryAgainDelay,
                   sleep: sleep,
                   report: { [box] in box.reported.append(AppError.wrapping($0)) },
                   leavesOutcomeUnknown: { $0 == .network || $0 == .eventCreationFailed },
                   notFound: .eventNotFound,
                   lookup: { [box] _ in
                       box.lookups += 1
                       return try box.lookup.get()
                   },
                   isOurs: \.mine)
    }

    /// One create through the flow, with a fixed tail for the success line; the update answers from the box.
    private func submit(_ send: () async throws -> Thing) async -> Thing? {
        await makeFlow().submit(clientID: "c-1",
                                describing: { _ in "(two spots)" },
                                send: send,
                                update: { [box] in try box.update() })
    }
}
