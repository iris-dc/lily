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
    private var freshness = ContentFreshness.standard

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

    /// True until the first answer, success or failure, so a screen shows its spinner through a location wait and never
    /// an empty state before the list was asked.
    var isInitialLoad: Bool { !freshness.hasLoaded && !loadFailed }
    var listState: ListState {
        ListState(isInitialLoad: isInitialLoad, isEmpty: visibleTournaments.isEmpty, loadFailed: loadFailed)
    }
    /// True from a failed load until the next successful one.
    var loadFailed: Bool { freshness.loadFailed }
    var hasLoaded: Bool { freshness.hasLoaded }

    /// What the screen shows: every tournament of the scope, or those of the chosen type on Discover.
    var visibleTournaments: [Tournament] {
        typeFilter.map { type in tournaments.filter { $0.type == type } } ?? tournaments
    }

    /// Loads once per `AppConfig.Lists.staleAfter`, or sooner when a tournament changed elsewhere, the caller
    /// changed, or the position is not the one Explore content was loaded for (it became known after a load without
    /// one, or the user moved; the backend ranks by distance); a failed load waits `AppConfig.Lists.retryAfterFailure`
    /// unless one of those happened. A guest asks for nothing user-scoped: `.mine` is answered empty without a request.
    func loadIfStale() async {
        if scope == .mine, identity.currentUserID == nil {
            // An empty answer, not a reset: a guest's Mine is no initial load, and a sign-in makes it stale by caller.
            tournaments = []
            freshness.recordSuccess(at: now(), version: changes.version, userID: nil)
            return
        }
        guard !isWaitingToRetry else {
            logger.debug(.cache, "Tournaments for scope \(scope) failed to load recently; not retrying yet")
            return
        }
        guard let reason = stalenessReason else {
            logger.debug(.cache, "Tournaments for scope \(scope) are fresh; skipping reload")
            return
        }
        logger.debug(.cache, "Tournaments for scope \(scope) are stale (\(reason)); reloading")
        await load()
    }

    /// Always asks the repository (pull-to-refresh); a call made while one is in flight is dropped. A change that landed
    /// while the request was out (`replace`/`add`, a sign-in, on Explore a position that arrived or moved) may be
    /// missing from the answer, so it earns one reload at once; the recursion is bounded because a failed or cancelled
    /// load earns nothing and a fresh answer is stale only after such a landing.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        let succeeded = await performLoad(near: requestPosition)
        isLoading = false
        if succeeded, let reason = stalenessReason {
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
            freshness.recordSuccess(at: now(), version: version, userID: userID, position: position)
            logger.info(.tournaments,
                        "Loaded \(tournaments.count) tournaments for scope \(scope); with position: \(position != nil)")
            return true
        } catch {
            guard !AppError.isCancellation(error) else {
                logger.debug(.tournaments, "Loading tournaments cancelled for scope \(scope)")
                return false
            }
            freshness.recordFailure(at: now(), version: version, userID: userID)
            logger.error(.tournaments, "Loading tournaments failed for scope \(scope): \(error)")
            if reportsFailures { errorCenter.report(error) }
            return false
        }
    }

    /// Only Explore is ranked by distance; Home and a group's segment are their own lists, in start order.
    private var requestPosition: Coordinate? { scope == .upcoming ? userLocation : nil }

    /// Why the user's position makes Explore content stale (`ContentFreshness.positionReason`); the others send none.
    private var positionReason: String? { freshness.positionReason(for: requestPosition) }

    private var isWaitingToRetry: Bool {
        freshness.isWaitingToRetry(now: now(), version: changes.version, userID: identity.currentUserID)
    }

    /// Why the content must be reloaded, or `nil` while it can be reused: the shared rules first, then the position
    /// only Explore sends.
    private var stalenessReason: String? {
        freshness.stalenessReason(now: now(),
                                  version: changes.version,
                                  userID: identity.currentUserID,
                                  position: requestPosition)
    }

    /// Takes the tournament a detail just changed: in place while it still belongs to the scope, out of the list when
    /// it no longer does (a cancelled one on Explore, one the caller left on Home), and in by start when the list does
    /// not hold it yet (one entered on a detail pushed from a group's segment reaches Home's list at once). Recorded so
    /// every other list reloads on its next appearance; this one already shows the change.
    func replace(_ tournament: Tournament) {
        switch (tournaments.firstIndex(where: { $0.id == tournament.id }), belongs(tournament)) {
        case (let index?, true): tournaments[index] = tournament
        case (let index?, false): tournaments.remove(at: index)
        case (nil, true): insertByStart(tournament)
        case (nil, false): break
        }
        recordOwnChange("Tournament \(tournament.id) replaced in scope \(scope)")
    }

    /// Takes a tournament just created from this screen, by start, when it belongs to the scope; repeated for one id,
    /// a no-op. Recorded like `replace`.
    func add(_ tournament: Tournament) {
        guard !tournaments.contains(where: { $0.id == tournament.id }) else { return }
        if belongs(tournament) { insertByStart(tournament) }
        recordOwnChange("Tournament \(tournament.id) added to scope \(scope)")
    }

    /// Road distance from the user to a tournament, formatted; `nil` while the position is unknown.
    func distanceText(for tournament: Tournament) -> String? {
        tournament.distance(from: userLocation)?.roadText()
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

    private func insertByStart(_ tournament: Tournament) {
        let index = tournaments.firstIndex { $0.startsAt > tournament.startsAt } ?? tournaments.endIndex
        tournaments.insert(tournament, at: index)
    }

    /// This list already shows the change it applied; every other list reloads on its next appearance.
    private func recordOwnChange(_ what: String) {
        changes.recordChange()
        freshness.acknowledge(version: changes.version)
        logger.debug(.cache, "\(what); sibling lists invalidated")
    }
}
