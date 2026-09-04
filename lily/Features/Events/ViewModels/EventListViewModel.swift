import Foundation
import Observation

/// Drives every list of events (explore, my events, search). Scope decides which slice is loaded.
@Observable
final class EventListViewModel {
    private(set) var events: [SportEvent] = []
    private(set) var isLoading = false
    var searchText = ""

    private let scope: EventScope
    private let repository: any EventRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(scope: EventScope, repository: any EventRepository, errorCenter: ErrorCenter, logger: any Logging) {
        self.scope = scope
        self.repository = repository
        self.errorCenter = errorCenter
        self.logger = logger
    }

    var filteredEvents: [SportEvent] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return events }
        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(query)
                || event.sport.displayName.localizedCaseInsensitiveContains(query)
                || event.locationName.localizedCaseInsensitiveContains(query)
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await repository.events(in: scope)
            logger.info(.events, "Loaded \(events.count) events for scope \(scope)")
        } catch {
            logger.error(.events, "Loading events failed for scope \(scope): \(error)")
            errorCenter.report(AppError.eventsUnavailable)
        }
    }
}
