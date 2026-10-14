import Testing
@testable import lily

/// What the gate handed to `report`, as the popup would receive it.
@MainActor
private final class Reported {
    var errors: [AppError] = []
}

@MainActor
struct WriteGateTests {
    private let logger = SpyLogger()
    private let reported = Reported()

    @Test func aWriteThatGoesThroughAnswersTrueAndLogsNothing() async {
        let script = ScriptedAttempt([.success(1)])

        let wentThrough = await run(script)

        #expect(wentThrough)
        #expect(script.attempts == 1)
        #expect(logger.messages(in: .groups).isEmpty && reported.errors.isEmpty)
    }

    @Test func aLostRaceIsRepeatedOnceInsideTheGate() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .success(1)])

        let wentThrough = await run(script)

        #expect(wentThrough)
        #expect(script.attempts == 2)
        #expect(logger.count(in: .groups, at: .info) == 1)
        #expect(logger.hasLine(in: .groups, at: .info, mentioning: "Remove", "group g", "retrying once"))
        #expect(logger.messages(in: .groups, at: .error).isEmpty && reported.errors.isEmpty)
    }

    @Test func aSecondLostRaceIsReportedLikeAnyOtherRefusal() async {
        let script = ScriptedAttempt([.failure(AppError.tryAgain), .failure(AppError.tryAgain)])

        let wentThrough = await run(script)

        #expect(!wentThrough)
        #expect(script.attempts == 2)
        #expect(logger.count(in: .groups, at: .error) == 1)
        #expect(logger.hasLine(in: .groups, at: .error, mentioning: "group g", "\(AppError.tryAgain)"))
        #expect(reported.errors == [.tryAgain])
    }

    @Test func aFailureIsLoggedAtErrorReportedAndAnswersFalse() async {
        let script = ScriptedAttempt([.failure(AppError.notAMember)])

        let wentThrough = await run(script)

        #expect(!wentThrough)
        #expect(logger.count(in: .groups, at: .error) == 1)
        #expect(logger.hasLine(in: .groups, at: .error, mentioning: "group g", "\(AppError.notAMember)"))
        #expect(logger.messages(in: .groups, at: .warning).isEmpty)
        #expect(reported.errors == [.notAMember])
    }

    @Test func anExpectedRefusalIsLoggedAtWarningAndStillReported() async {
        let script = ScriptedAttempt([.failure(AppError.notAMember)])

        let wentThrough = await run(script, gate: makeGate(isExpected: { $0 == .notAMember }))

        #expect(!wentThrough)
        #expect(logger.count(in: .groups, at: .warning) == 1)
        #expect(logger.hasLine(in: .groups, at: .warning, mentioning: "group g", "\(AppError.notAMember)"))
        #expect(logger.count(in: .groups, at: .error) == 0, "an expected refusal is a warning, not an error")
        #expect(reported.errors == [.notAMember])
    }

    @Test func anUnexpectedRefusalStaysAtErrorWhenAnotherOneIsExpected() async {
        let script = ScriptedAttempt([.failure(AppError.insufficientRole)])

        let wentThrough = await run(script, gate: makeGate(isExpected: { $0 == .notAMember }))

        #expect(!wentThrough)
        #expect(logger.count(in: .groups, at: .error) == 1)
        #expect(logger.hasLine(in: .groups, at: .error, mentioning: "group g", "\(AppError.insufficientRole)"))
        #expect(logger.messages(in: .groups, at: .warning).isEmpty)
    }

    @Test func cancellationStaysQuietAndAnswersFalse() async {
        let script = ScriptedAttempt([.failure(CancellationError())])

        let wentThrough = await run(script)

        #expect(!wentThrough)
        #expect(logger.messages(in: .groups).isEmpty && reported.errors.isEmpty)
    }

    /// The gate the roster's actions would build, with no pause before the repeat.
    private func makeGate(isExpected: @escaping (AppError) -> Bool = { _ in false }) -> WriteGate {
        WriteGate(category: .groups,
                  logger: logger,
                  tryAgainDelay: .zero,
                  report: { [reported] in reported.errors.append(AppError.wrapping($0)) },
                  isExpected: isExpected)
    }

    /// One write through the gate with the wording the roster's Remove uses.
    private func run(_ script: ScriptedAttempt, gate: WriteGate? = nil) async -> Bool {
        await (gate ?? makeGate()).run("Remove in group g") { _ = try script.next() }
    }
}
