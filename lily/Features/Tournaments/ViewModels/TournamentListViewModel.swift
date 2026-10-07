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
    /// The position the current content was asked for, as `Coordinate.coarse` (the rounding the backend, which ranks
    /// by distance, receives); `nil` after a load without one. Explore content for another position than the user's
    /// now is stale, as the events list's is.
    private var loadedPosition: Coordinate?

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

    /// Loads once per `AppConfig.Tournaments.listStaleAfter`, or sooner when a tournament changed elsewhere, the
    /// caller changed, or the position is not the one Explore content was loaded for (it became known after a load
    /// without one, or the user moved; the backend ranks by distance); a failed load waits `retryAfterFailure` unless
    /// one of those happened. A guest asks for nothing user-scoped: `.mine` is cleared without a request.
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
        guard let reason = freshness.stalenessReason(now: now(), version: version, userID: userID) ?? positionReason else {
            logger.debug(.cache, "Tournaments for scope \(scope) are fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Tournaments for scope \(scope) are stale (\(reason)); reloading")
        await load()
    }

    /// Always asks the repository (pull-to-refresh). A call made while one is in flight is dropped. Explore sends the
    /// user's position when known; one that arrived or moved while the request was out earns one reload right away.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let succeeded = await performLoad(near: requestPosition)
        isLoading = false
        if succeeded, let reason = positionReason {
            logger.debug(.cache, "Tournaments for scope \(scope): \(reason) while loading; reloading")
            await load()
        }
    }

    /// Asks for the position on every appearance (the cache answers within its TTL): the distances need it, and
    /// Explore content loaded for another position (or none) is stale then; a load in flight notices the position
    /// itself when it finishes.
    func loadUserLocation() async {
        if let fix = await locationService.currentLocation() { userLocation = fix }
        if positionReason != nil, !isLoading {
            await loadIfStale()
        }
    }

    /// One request and its bookkeeping; answers whether it succeeded. Version and caller are taken before the request:
    /// a change or a sign-in landing mid-flight may be missing from the answer, and must reload.
    private func performLoad(near position: Coordinate?) async -> Bool {
        let version = changes.version
        let userID = identity.currentUserID
        do {
            tournaments = try await repository.tournaments(in: scope, near: position)
            freshness.recordSuccess(at: now(), version: version, userID: userID)
            loadedPosition = position?.coarse
            logger.info(.tournaments,
                        "Loaded \(tournaments.count) tournaments for scope \(scope); with position: \(position != nil)")
            return true
        } catch {
            guard !AppError.isCancellation(error) else { return false }
            freshness.recordFailure(at: now(), version: version, userID: userID)
            logger.error(.tournaments, "Loading tournaments failed for scope \(scope): \(error)")
            if reportsFailures { errorCenter.report(error) }
            return false
        }
    }

    /// Only Explore is ranked by distance; Home and a group's segment are their own lists, in start order.
    private var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Why the user's position makes the content stale, or `nil`: it was loaded without one that is known now, or for
    /// another one than the user's now.
    private var positionReason: String? {
        guard freshness.hasLoaded, let position = requestPosition?.coarse else { return nil }
        guard let loadedPosition else { return "position became known" }
        return loadedPosition == position ? nil : "position changed"
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
