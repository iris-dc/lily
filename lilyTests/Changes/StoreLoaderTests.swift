import Foundation
import Testing
@testable import lily

/// The load skeleton the app-lifetime stores share, judged on its own over a scripted fetch: what `MyGroupsStore` and
/// `InboxStore` only wire.
@MainActor
struct StoreLoaderTests {
    /// The clock, the change counter and the fetch's answer, all under the test's hand; the hold parks a fetch.
    @MainActor
    private final class Script {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        var version = 0
        var answer: Result<Int, any Error> = .success(1)
        var fetches = 0
        var applied: [Int] = []
        let hold = RequestHold()
    }

    private let script = Script()
    private let identity = FakeIdentityProvider(currentUserID: "u")
    private let logger = SpyLogger()
    private let errorCenter: ErrorCenter
    private let loader: StoreLoader
    private let fetch: () async throws -> Int
    private let apply: (Int) -> Void

    init() {
        errorCenter = ErrorCenter(logger: logger)
        let script = script
        loader = StoreLoader(noun: "things",
                             category: .groups,
                             identity: identity,
                             errorCenter: errorCenter,
                             logger: logger,
                             now: { script.clock },
                             version: { script.version })
        fetch = {
            await script.hold.wait()
            script.fetches += 1
            return try script.answer.get()
        }
        apply = { script.applied.append($0) }
    }

    private func loadIfStale() async {
        await loader.loadIfStale(fetch: fetch, apply: apply)
    }

    private func reload() async {
        await loader.reload(fetch: fetch, apply: apply)
    }

    /// A reload started in the background, so the test can act while the fetch is held.
    private func startReload() -> Task<Void, Never> {
        let (loader, fetch, apply) = (loader, fetch, apply)
        return Task { await loader.reload(fetch: fetch, apply: apply) }
    }

    private func startLoadIfStale() -> Task<Void, Never> {
        let (loader, fetch, apply) = (loader, fetch, apply)
        return Task { await loader.loadIfStale(fetch: fetch, apply: apply) }
    }

    private var cacheLines: [String] { logger.messages(in: .cache, at: .debug) }

    @Test func aFirstLoadFetchesAndApplies() async {
        await loadIfStale()

        #expect(script.fetches == 1 && script.applied == [1])
        #expect(loader.hasLoaded && !loader.loadFailed && !loader.isLoading)
        #expect(cacheLines.contains("Reloading things: never loaded"))
    }

    @Test func aFreshLoadIsReusedUntilTheTTLOrTheVersionMoves() async {
        await loadIfStale()

        await loadIfStale()
        #expect(script.fetches == 1)
        #expect(cacheLines.contains("Reusing things: fresh"))

        script.clock = script.clock.addingTimeInterval(AppConfig.Lists.staleAfter)
        await loadIfStale()
        #expect(script.fetches == 2)
        #expect(cacheLines.contains("Reloading things: older than TTL"))

        script.version += 1
        await loadIfStale()
        #expect(script.fetches == 3)
        #expect(cacheLines.contains("Reloading things: changed elsewhere"))
    }

    @Test func aFailureIsReportedAndWaitsForTheCooldownUnlessTheVersionMoved() async {
        script.answer = .failure(AppError.groupsUnavailable)

        await loadIfStale()
        #expect(loader.loadFailed && !loader.hasLoaded && script.applied.isEmpty)
        #expect(errorCenter.current?.error == .groupsUnavailable)
        #expect(logger.count(in: .groups, at: .error) == 1)
        #expect(logger.hasLine(in: .groups, at: .error, mentioning: "things", "\(AppError.groupsUnavailable)"))

        await loadIfStale()
        #expect(script.fetches == 1)
        #expect(cacheLines.contains("Not retrying things yet: a load failed recently"))

        script.version += 1
        await loadIfStale()
        #expect(script.fetches == 2, "a change elsewhere ends the wait")
    }

    @Test func theCooldownAfterAFailurePassesWithTheClock() async {
        script.answer = .failure(AppError.groupsUnavailable)
        await loadIfStale()

        script.clock = script.clock.addingTimeInterval(AppConfig.Lists.retryAfterFailure)
        await loadIfStale()

        #expect(script.fetches == 2)
        #expect(cacheLines.contains("Reloading things: retry after failure"))
    }

    @Test func cancellationStaysQuiet() async {
        script.answer = .failure(CancellationError())

        await loadIfStale()

        #expect(!loader.loadFailed && !loader.hasLoaded)
        #expect(errorCenter.current == nil)
        #expect(logger.count(in: .groups, at: .debug) == 1)
        #expect(logger.hasLine(in: .groups, at: .debug, mentioning: "things", "cancelled"))
        #expect(logger.messages(in: .groups, at: .error).isEmpty)
    }

    @Test func anAnswerForAPreviousCallerIsDropped() async {
        script.hold.isEnabled = true
        let run = startReload()
        await settle(until: { script.hold.isHolding })

        identity.currentUserID = nil
        script.hold.release()
        await run.value

        #expect(script.fetches == 1 && script.applied.isEmpty)
        #expect(!loader.hasLoaded && !loader.isLoading)
        #expect(cacheLines.contains("Answer for things for a previous caller dropped"))
    }

    @Test func aVersionThatMovedDuringTheRequestLoadsOnceMore() async {
        script.hold.isEnabled = true
        let run = startReload()
        await settle(until: { script.hold.isHolding })

        script.version += 1
        script.hold.release()
        await run.value

        #expect(script.fetches == 2 && script.applied.count == 2)
        #expect(cacheLines.contains("Version moved while loading things; loading once more"))

        await loadIfStale()
        #expect(script.fetches == 2, "the repeat recorded the moved version")
    }

    /// A call made while a request is out for the same caller joins it instead of asking again. The second call is a
    /// `loadIfStale`, whose "Reloading" line is written right before it reaches the single flight, so the test knows
    /// it has joined before the first fetch is let through.
    @Test func aLoadWhileOneIsInFlightJoinsIt() async {
        script.hold.isEnabled = true
        let first = startReload()
        await settle(until: { script.hold.isHolding })
        let second = startLoadIfStale()
        await settle(until: { cacheLines.contains("Reloading things: never loaded") })

        script.hold.release()
        await first.value
        await second.value

        #expect(script.fetches == 1 && script.applied == [1])
        #expect(!loader.isLoading && loader.hasLoaded)
    }

    @Test func aGuestIsNotAsked() async {
        identity.currentUserID = nil

        await loadIfStale()
        await reload()

        #expect(script.fetches == 0 && !loader.hasLoaded && !loader.isLoading)
        #expect(logger.entries.isEmpty)
    }

    @Test func acknowledgeKeepsTheContentFreshAndResetForgetsIt() async {
        await loadIfStale()

        script.version += 1
        loader.acknowledge(version: 1)
        await loadIfStale()
        #expect(script.fetches == 1)

        loader.reset()
        #expect(!loader.hasLoaded)
        await loadIfStale()
        #expect(script.fetches == 2)
        #expect(cacheLines.last == "Reloading things: never loaded")
    }
}
