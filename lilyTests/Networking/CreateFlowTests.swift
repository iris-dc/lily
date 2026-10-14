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

    /// The flow an event form would build, over the box's lookup.
    private func makeFlow() -> CreateFlow<Thing> {
        CreateFlow(noun: "thing",
                   category: .events,
                   logger: logger,
                   report: { [box] in box.reported.append(AppError.wrapping($0)) },
                   leavesOutcomeUnknown: { $0 == .network || $0 == .eventCreationFailed },
                   notFound: .eventNotFound,
                   lookup: { [box] _ in
                       box.lookups += 1
                       return try box.lookup.get()
                   },
                   isOurs: \.mine)
    }

    /// One create through the flow, with a fixed tail for the success line.
    private func submit(_ send: () async throws -> Thing) async -> Thing? {
        await makeFlow().submit(clientID: "c-1", describing: { _ in "(two spots)" }, send: send)
    }
}
