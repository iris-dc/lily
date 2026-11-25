import Foundation
import Observation

/// The caller's own history on Profile: the games they joined that have started (`EventScope.past`) and the finished
/// tournaments among their rooms (`.mine` keeps them; a cancelled one is no history, as on a profile's shared lists).
/// Both lists land in one state, so the screen shows one spinner and one retry for all of it.
@Observable
final class ActivityViewModel {
    enum State: Equatable {
        case loading
        case loaded(Activity)
        /// The popup said what went wrong; the screen offers to try again.
        case failed
    }

    /// What the screen shows, already reduced to the rows' summaries, each list the latest start first.
    nonisolated struct Activity: Equatable, Sendable {
        let events: [EventSummary]
        let tournaments: [TournamentSummary]
    }

    private(set) var state: State = .loading

    private let events: any EventRepository
    private let tournaments: any TournamentRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging
    private var hasLoggedOpen = false

    init(events: any EventRepository,
         tournaments: any TournamentRepository,
         errorCenter: ErrorCenter,
         logger: any Logging) {
        self.events = events
        self.tournaments = tournaments
        self.errorCenter = errorCenter
        self.logger = logger
    }

    var activity: Activity? {
        if case .loaded(let activity) = state { return activity }
        return nil
    }

    /// Loads both lists together, or reloads them on retry; a history already on screen stays while the request runs
    /// and when it fails, as a profile keeps its shared lists.
    func load() async {
        logOpenOnce()
        if activity == nil { state = .loading }
        do {
            async let pastGames = events.events(in: .past, near: nil)
            async let mine = tournaments.tournaments(in: .mine, near: nil)
            state = .loaded(Self.reduce(games: try await pastGames, rooms: try await mine))
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.events, "Loading history failed: \(error)")
            if activity == nil { state = .failed }
            errorCenter.report(error)
        }
    }

    /// The games come past already, the latest first; sorting again costs nothing and frees the screen from trusting
    /// the order. Mine holds every status, so the finished tournaments are picked out here.
    nonisolated private static func reduce(games: [SportEvent], rooms: [Tournament]) -> Activity {
        Activity(events: games.sorted { $0.startsAt > $1.startsAt }.map { EventSummary($0) },
                 tournaments: rooms.filter { $0.status == .completed }
                     .sorted { $0.startsAt > $1.startsAt }
                     .map { TournamentSummary($0) })
    }

    /// One line per screen instance, however often the view's task restarts.
    private func logOpenOnce() {
        guard !hasLoggedOpen else { return }
        hasLoggedOpen = true
        logger.info(.events, "Activity opened")
    }
}
