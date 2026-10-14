import Testing
@testable import lily

@MainActor
struct LostRaceTests {
    private let logger = SpyLogger()

    @Test func aFirstSuccessAnswersWithoutARetryOrALogLine() async throws {
        let script = ScriptedAttempt([.success(7)])

        let value = try await attempt(script)

        #expect(value == 7)
        #expect(script.attempts == 1)
        #expect(logger.messages(in: .events).isEmpty)
    }

    @Test func aLostRaceIsRepeatedOnceAndLoggedOnce() async throws {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .success(7)])

        let value = try await attempt(script)

        #expect(value == 7)
        #expect(script.attempts == 2)
        #expect(logger.messages(in: .events, at: .info) == ["Join for event e lost a race; retrying once"])
    }

    @Test func aSecondLostRaceIsThrown() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .failure(AppError.tryAgain)])

        let error = await thrown { try await attempt(script) }

        #expect(error as? AppError == AppError.tryAgain)
        #expect(script.attempts == 2)
        #expect(logger.messages(in: .events, at: .info).count == 1)
    }

    @Test func anotherRefusalOnTheFirstAttemptIsThrownWithoutARetry() async {
        let script = ScriptedAttempt([.failure(AppError.eventFull)])

        let error = await thrown { try await attempt(script) }

        #expect(error as? AppError == AppError.eventFull)
        #expect(script.attempts == 1)
        #expect(logger.messages(in: .events).isEmpty)
    }

    @Test func anotherRefusalOnTheSecondAttemptIsThrown() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .failure(AppError.eventFull)])

        let error = await thrown { try await attempt(script) }

        #expect(error as? AppError == AppError.eventFull)
        #expect(script.attempts == 2)
    }

    @Test func cancellationPassesThroughUntouched() async {
        let script = ScriptedAttempt([.failure(CancellationError())])

        let error = await thrown { try await attempt(script) }

        #expect(error is CancellationError)
        #expect(script.attempts == 1)
        #expect(logger.messages(in: .events).isEmpty)
    }

    @Test func theSecondAttemptWaitsForThePause() async throws {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .success(7)])
        let sleep = HeldSleep()

        let run = Task { [logger] in
            try await LostRace.attemptTwice(delay: .milliseconds(400),
                                            sleep: { [sleep] in try await sleep.sleep(for: $0) },
                                            logger: logger,
                                            category: .events,
                                            retrying: "Join for event e",
                                            { try script.next() })
        }
        await settle(until: { sleep.held == [.milliseconds(400)] })
        #expect(script.attempts == 1)

        sleep.release()
        let value = try await run.value

        #expect(value == 7)
        #expect(script.attempts == 2)
    }

    /// The call every case makes: no pause, the events category and the wording the event detail uses.
    private func attempt(_ script: ScriptedAttempt) async throws -> Int {
        try await LostRace.attemptTwice(delay: .zero, logger: logger, category: .events, retrying: "Join for event e") {
            try script.next()
        }
    }

    private func thrown(_ work: () async throws -> Int) async -> (any Error)? {
        do {
            _ = try await work()
            return nil
        } catch {
            return error
        }
    }
}
