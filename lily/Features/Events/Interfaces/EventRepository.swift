import Foundation

/// Read boundary for events. The real implementation will sit on top of an on-device cache in front of the API.
protocol EventRepository {
    func events(in scope: EventScope) async throws -> [SportEvent]
}
