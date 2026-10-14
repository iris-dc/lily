import Foundation

/// When content a screen or store holds can be reused and when it must be fetched again. Shared by every list that
/// caches a backend answer (the events lists, Mine, the inbox, the tournament lists) through `standard`, so the rules
/// are decided once: a TTL, the change counter the content reflects, the caller it was loaded for (`isJoined` and
/// memberships are per caller), a cooldown after a failed load, so switching tabs while the backend is down neither
/// hammers it nor repeats the popup, and, for the lists the backend orders by distance, the position they were loaded
/// for.
nonisolated struct ContentFreshness: Equatable, Sendable {
    private struct FailedAttempt: Equatable {
        let at: Date
        let version: Int
        let userID: String?
    }

    /// What a store does with the content it holds, decided from the rules below in one place so the load prologues
    /// become one `switch`.
    enum LoadDecision: Equatable, Sendable {
        /// A load failed within the cooldown and nothing changed since: do not ask yet.
        case waitAfterFailure
        case fresh
        /// The content must be fetched again, for this reason (`stalenessReason`'s wording).
        case stale(reason: String)
    }

    let staleAfter: TimeInterval
    let retryAfterFailure: TimeInterval
    private(set) var lastLoadedAt: Date?
    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    private(set) var loadFailed = false
    private var loadedVersion: Int?
    private var loadedUserID: String?
    /// The position the content was loaded for, as `Coordinate.coarse`, the rounding the backend receives, so drift
    /// within it never counts; `nil` after a load without one.
    private var loadedPosition: Coordinate?
    private var failedAttempt: FailedAttempt?

    /// What every list starts from: the TTL and cooldown of `AppConfig.Lists`; a value type, so each list mutates its
    /// own copy.
    static let standard = ContentFreshness(staleAfter: AppConfig.Lists.staleAfter,
                                           retryAfterFailure: AppConfig.Lists.retryAfterFailure)

    init(staleAfter: TimeInterval, retryAfterFailure: TimeInterval) {
        self.staleAfter = staleAfter
        self.retryAfterFailure = retryAfterFailure
    }

    var hasLoaded: Bool { lastLoadedAt != nil }

    /// Version and caller are the ones taken before the request: a change or a sign-in landing mid-flight may be
    /// missing from the answer, and must make it stale. `position` is the one the request carried, `nil` for a list
    /// that sends none.
    mutating func recordSuccess(at now: Date, version: Int, userID: String?, position: Coordinate? = nil) {
        lastLoadedAt = now
        loadedVersion = version
        loadedUserID = userID
        loadedPosition = position?.coarse
        failedAttempt = nil
        loadFailed = false
    }

    mutating func recordFailure(at now: Date, version: Int, userID: String?) {
        failedAttempt = FailedAttempt(at: now, version: version, userID: userID)
        loadFailed = true
    }

    /// The content was changed in place to match a change recorded at `version`, so it is current for it.
    mutating func acknowledge(version: Int) {
        loadedVersion = version
    }

    mutating func reset() {
        self = ContentFreshness(staleAfter: staleAfter, retryAfterFailure: retryAfterFailure)
    }

    /// True from a failed load until `retryAfterFailure` has passed, unless a change made elsewhere or a change of
    /// caller since then means the answer is different anyway, which proves the backend is up.
    func isWaitingToRetry(now: Date, version: Int, userID: String?) -> Bool {
        guard loadFailed, let failedAttempt else { return false }
        guard failedAttempt.version == version, failedAttempt.userID == userID else { return false }
        return now.timeIntervalSince(failedAttempt.at) < retryAfterFailure
    }

    /// The cooldown first, then the staleness reasons: what `isWaitingToRetry` and `stalenessReason` answer, as one
    /// decision.
    func decision(now: Date, version: Int, userID: String?, position: Coordinate? = nil) -> LoadDecision {
        if isWaitingToRetry(now: now, version: version, userID: userID) { return .waitAfterFailure }
        guard let reason = stalenessReason(now: now, version: version, userID: userID, position: position) else {
            return .fresh
        }
        return .stale(reason: reason)
    }

    /// Why the content must be reloaded, or `nil` while it can be reused: the shared reasons first, the position last.
    func stalenessReason(now: Date, version: Int, userID: String?, position: Coordinate? = nil) -> String? {
        guard let lastLoadedAt else { return loadFailed ? "retry after failure" : "never loaded" }
        if loadedVersion != version { return "changed elsewhere" }
        if loadedUserID != userID { return "caller changed" }
        if loadFailed { return "retry after failure" }
        if now.timeIntervalSince(lastLoadedAt) >= staleAfter { return "older than TTL" }
        return positionReason(for: position)
    }

    /// Why the position alone makes the content stale, or `nil`: it was loaded without one that is known now, or for
    /// another one than `position`, the one a request would carry now (`nil` for a list that sends none), so the
    /// backend can order it better. Never a reason before a load.
    func positionReason(for position: Coordinate?) -> String? {
        guard hasLoaded, let position = position?.coarse else { return nil }
        guard let loadedPosition else { return "position became known" }
        return loadedPosition == position ? nil : "position changed"
    }
}
