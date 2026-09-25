import Foundation

/// When content a screen or store holds can be reused and when it must be fetched again. Shared by every list that
/// caches a backend answer (events, groups), so the rules are decided once: a TTL, the change counter the content
/// reflects, the caller it was loaded for (`isJoined` and memberships are per caller), and a cooldown after a failed
/// load, so switching tabs while the backend is down neither hammers it nor repeats the popup.
nonisolated struct ContentFreshness: Equatable, Sendable {
    private struct FailedAttempt: Equatable {
        let at: Date
        let version: Int
        let userID: String?
    }

    let staleAfter: TimeInterval
    let retryAfterFailure: TimeInterval
    private(set) var lastLoadedAt: Date?
    /// True from a failed load until the next successful one, so the screen can say so instead of "nothing yet".
    private(set) var loadFailed = false
    private var loadedVersion: Int?
    private var loadedUserID: String?
    private var failedAttempt: FailedAttempt?

    init(staleAfter: TimeInterval, retryAfterFailure: TimeInterval) {
        self.staleAfter = staleAfter
        self.retryAfterFailure = retryAfterFailure
    }

    var hasLoaded: Bool { lastLoadedAt != nil }

    /// Version and caller are the ones taken before the request: a change or a sign-in landing mid-flight may be
    /// missing from the answer, and must make it stale.
    mutating func recordSuccess(at now: Date, version: Int, userID: String?) {
        lastLoadedAt = now
        loadedVersion = version
        loadedUserID = userID
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

    /// Why the content must be reloaded, or `nil` while it can be reused.
    func stalenessReason(now: Date, version: Int, userID: String?) -> String? {
        guard let lastLoadedAt else { return loadFailed ? "retry after failure" : "never loaded" }
        if loadedVersion != version { return "changed elsewhere" }
        if loadedUserID != userID { return "caller changed" }
        if loadFailed { return "retry after failure" }
        if now.timeIntervalSince(lastLoadedAt) >= staleAfter { return "older than TTL" }
        return nil
    }
}
