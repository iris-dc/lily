import Foundation
import Observation

/// Drives every list of tournaments: the Explore carousel and Discover (`.upcoming`), Home's section (`.mine`) and a
/// group's segment (`.group`). Scope decides which slice is loaded; Discover narrows `.upcoming` by type on device.
@Observable
final class TournamentListViewModel {
    let scope: TournamentScope
    private(set) var tournaments: [Tournament] = []
    private(set) var isLoading = false
    private(set) var userLocation: Coordinate?
    /// Discover's one criterion, applied on device; `nil` is any type.
    var typeFilter: EventType?
    /// Off for the carousel on Explore: the events list there reports its own failure, and a second popup would only
    /// repeat it.
    var reportsFailures = true

    private let repository: any TournamentRepository
    private let identity: any IdentityProvider
    private let locationService: any LocationService
    private let changes: ChangeTracker
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private let now: () -> Date
    private var freshness = ContentFreshness(staleAfter: AppConfig.Tournaments.listStaleAfter,
                                             retryAfterFailure: AppConfig.Tournaments.retryAfterFailure)

    init(scope: TournamentScope,
         repository: any TournamentRepository,
         identity: any IdentityProvider,
         locationService: any LocationService,
         changes: ChangeTracker,
         errorCenter: ErrorCenter,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.scope = scope
        self.repository = repository
        self.identity = identity
        self.locationService = locationService
        self.changes = changes
        self.errorCenter = errorCenter
        self.logger = logger
        self.now = now
    }

    /// The very first load, before any result exists.
    var isInitialLoad: Bool { isLoading && !freshness.hasLoaded && !loadFailed }
    /// True from a failed load until the next successful one.
    var loadFailed: Bool { freshness.loadFailed }
    var hasLoaded: Bool { freshness.hasLoaded }

    /// What the screen shows: every tournament of the scope, or those of the chosen type on Discover.
    var visibleTournaments: [Tournament] {
        typeFilter.map { type in tournaments.filter { $0.type == type } } ?? tournaments
    }

    /// Loads once per `AppConfig.Tournaments.listStaleAfter`, or sooner when a tournament changed elsewhere or the
    /// caller changed; a failed load waits `retryAfterFailure` unless one of those happened. A guest asks for nothing
    /// user-scoped: `.mine` is cleared without a request.
    func loadIfStale() async {
        if scope == .mine, identity.currentUserID == nil {
            tournaments = []
            freshness.reset()
            return
        }
        let version = changes.version
        let userID = identity.currentUserID
        guard !freshness.isWaitingToRetry(now: now(), version: version, userID: userID) else {
            logger.debug(.cache, "Tournaments for scope \(scope) failed to load recently; not retrying yet")
            return
        }
        guard let reason = freshness.stalenessReason(now: now(), version: version, userID: userID) else {
            logger.debug(.cache, "Tournaments for scope \(scope) are fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Tournaments for scope \(scope) are stale (\(reason)); reloading")
        await load()
    }

    /// Always asks the repository (pull-to-refresh). A call made while one is in flight is dropped.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let version = changes.version
        let userID = identity.currentUserID
        do {
            tournaments = try await repository.tournaments(in: scope, near: scope == .upcoming ? userLocation : nil)
            freshness.recordSuccess(at: now(), version: version, userID: userID)
            logger.info(.tournaments, "Loaded \(tournaments.count) tournaments for scope \(scope)")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            freshness.recordFailure(at: now(), version: version, userID: userID)
            logger.error(.tournaments, "Loading tournaments failed for scope \(scope): \(error)")
            if reportsFailures { errorCenter.report(error) }
        }
    }

    /// Asks for the position on every appearance (the cache answers within its TTL); distances need it, nothing else.
    func loadUserLocation() async {
        if let fix = await locationService.currentLocation() { userLocation = fix }
    }

    /// Takes the tournament a detail just changed: in place, or out of a list it no longer belongs to (a cancelled
    /// one on Explore, one the caller left on Home). Recorded so every other list reloads on its next appearance.
    func replace(_ tournament: Tournament) {
        if let index = tournaments.firstIndex(where: { $0.id == tournament.id }) {
            if belongs(tournament) {
                tournaments[index] = tournament
            } else {
                tournaments.remove(at: index)
            }
        }
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "Tournament \(tournament.id) replaced in scope \(scope); sibling lists invalidated")
    }

    /// Takes a tournament just created from this screen, by start, when it belongs to the scope; repeated for one id,
    /// a no-op. Recorded like `replace`.
    func add(_ tournament: Tournament) {
        guard !tournaments.contains(where: { $0.id == tournament.id }) else { return }
        if belongs(tournament) {
            let index = tournaments.firstIndex { $0.startsAt > tournament.startsAt } ?? tournaments.endIndex
            tournaments.insert(tournament, at: index)
        }
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "Tournament \(tournament.id) added to scope \(scope); sibling lists invalidated")
    }

    /// Road distance from the user to a tournament, formatted; `nil` while the position is unknown.
    func distanceText(for tournament: Tournament) -> String? {
        tournament.distance(from: userLocation)?.roadText
    }

    /// The backend's listing rule repeated on device: Explore lists public tournaments in registration, Home the
    /// caller's (organised or entered), a group's segment its own but the cancelled.
    private func belongs(_ tournament: Tournament) -> Bool {
        switch scope {
        case .upcoming: tournament.isListed
        case .mine: tournament.isOrganized(by: identity.currentUserID) || tournament.hasEntered
        case .group(let id): tournament.group?.id == id && tournament.status != .cancelled
        }
    }
}
