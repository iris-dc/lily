import Foundation
import Observation

/// The load skeleton the app-lifetime stores share: content reused while `ContentFreshness` calls it fresh (TTL, the
/// version `version()` answers, the caller), a failed load waiting out the cooldown, one request at a time through
/// `SingleFlight` (a call for the same caller joins it, one for another waits it out), an answer for a caller who signed
/// out or changed meanwhile dropped, a cancellation quiet, a failure logged under `category` and reported, and a version
/// that moved while the request was out loaded once more, exactly once. The store keeps what an answer means (`apply`)
/// and clears itself for a guest; the loader keeps the bookkeeping.
@Observable
final class StoreLoader {
    private let load = SingleFlight()
    private var freshness = ContentFreshness.standard
    /// Names the content in the log lines ("groups", "the inbox"), which read "Loading <noun> cancelled".
    private let noun: String
    private let category: LogCategory
    private let identity: any IdentityProvider
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date
    /// The change counter the content reflects; a store whose content changes nowhere else answers a constant.
    private let version: () -> Int

    init(noun: String,
         category: LogCategory,
         identity: any IdentityProvider,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date,
         version: @escaping () -> Int) {
        self.noun = noun
        self.category = category
        self.identity = identity
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
        self.version = version
    }

    var isLoading: Bool { load.isRunning }
    /// True from a failed load until the next successful one.
    var loadFailed: Bool { freshness.loadFailed }
    var hasLoaded: Bool { freshness.hasLoaded }

    /// Loads once per `AppConfig.Lists.staleAfter`, or sooner when the version or the caller changed; after a failed
    /// load it waits `AppConfig.Lists.retryAfterFailure` unless one of those happened. A guest is asked nothing.
    func loadIfStale<Fetched>(fetch: @escaping () async throws -> Fetched, apply: @escaping (Fetched) -> Void) async {
        guard let userID = identity.currentUserID else { return }
        switch freshness.decision(now: now(), version: version(), userID: userID) {
        case .waitAfterFailure:
            logger.debug(.cache, "Not retrying \(noun) yet: a load failed recently")
        case .fresh:
            logger.debug(.cache, "Reusing \(noun): fresh")
        case .stale(let reason):
            logger.debug(.cache, "Reloading \(noun): \(reason)")
            await reload(fetch: fetch, apply: apply)
        }
    }

    /// Always asks the backend (pull-to-refresh, the resume protocol). A call made while one is in flight for the same
    /// user joins it; one for another user waits it out and then loads for them. A change recorded anywhere while the
    /// request was out means the answer predates it: the answer is applied, so the screen is never empty, and the load
    /// runs once more, exactly once; both requests run inside the same `SingleFlight` task, so `isLoading` stays true
    /// through the repeat.
    func reload<Fetched>(fetch: @escaping () async throws -> Fetched, apply: @escaping (Fetched) -> Void) async {
        guard let userID = identity.currentUserID else { return }
        await load.run(key: userID) { [self] in
            guard await loadOnce(for: userID, fetch: fetch, apply: apply) else { return }
            logger.debug(.cache, "Version moved while loading \(noun); loading once more")
            _ = await loadOnce(for: userID, fetch: fetch, apply: apply)
        }
    }

    /// The content was changed in place to match a change recorded at `version`, so it is current for it.
    func acknowledge(version: Int) {
        freshness.acknowledge(version: version)
    }

    /// Forgets every load; the next `loadIfStale` asks again.
    func reset() {
        freshness.reset()
    }

    /// One request, applied for the caller it was made for. Answers whether `version()` moved while it was out;
    /// `false` after a dropped answer, a cancellation or a failure.
    private func loadOnce<Fetched>(for userID: String,
                                   fetch: () async throws -> Fetched,
                                   apply: (Fetched) -> Void) async -> Bool {
        let before = version()
        do {
            let fetched = try await fetch()
            guard identity.isStillCaller(userID, orDrop: "Answer for \(noun)", logger: logger) else { return false }
            apply(fetched)
            freshness.recordSuccess(at: now(), version: before, userID: userID)
            return version() != before
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(category, "Loading \(noun) cancelled")
                return false
            }
            guard identity.isStillCaller(userID, orDrop: "Answer for \(noun)", logger: logger) else { return false }
            freshness.recordFailure(at: now(), version: before, userID: userID)
            logger.error(category, "Loading \(noun) failed: \(error)")
            errorCenter.report(error)
            return false
        }
    }
}
