import Foundation
import Observation

/// Fetches the event behind an id-and-name destination (an event room's info button) before the detail can show it.
/// An event already loaded stays on screen while a reload runs and when it fails; `GroupLoaderViewModel`'s pattern.
@Observable
final class EventLoaderViewModel {
    enum State: Equatable {
        case loading
        case loaded(SportEvent)
        /// Deleted, or a private group's event the caller may not read: "This event is no longer available".
        case notFound
        /// Something else went wrong; the popup said what, the screen offers to try again.
        case failed
    }

    let destination: EventDestination
    private(set) var state: State = .loading

    private let repository: any EventRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(destination: EventDestination, repository: any EventRepository, errorCenter: ErrorCenter, logger: any Logging) {
        self.destination = destination
        self.repository = repository
        self.errorCenter = errorCenter
        self.logger = logger
    }

    /// The view's task: fetches once. A return from a pushed screen finds the event loaded and asks for nothing; a
    /// cancelled first attempt left `.loading` and is made again.
    func loadIfNeeded() async {
        guard state == .loading else { return }
        await load()
    }

    func load() async {
        if !hasLoadedEvent { state = .loading }
        do {
            state = .loaded(try await repository.event(id: destination.id))
        } catch AppError.eventNotFound {
            logger.info(.events, "Event \(destination.id) is not available to the caller")
            state = .notFound
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.events, "Loading event \(destination.id) failed: \(error)")
            if !hasLoadedEvent { state = .failed }
            errorCenter.report(error)
        }
    }

    private var hasLoadedEvent: Bool {
        if case .loaded = state { return true }
        return false
    }
}
