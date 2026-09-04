import Foundation

/// Deterministic fixture data until the backend exists.
final class MockEventRepository: EventRepository {
    /// Every n-th fixture counts as "joined" so the My Events tab has content.
    private static let joinedStride = 3

    private let fixtures: [SportEvent]
    private let logger: any Logging

    init(now: Date = .now, count: Int = AppConfig.Events.mockFeedSize, logger: any Logging) {
        self.fixtures = MockEventFixtures.make(now: now, count: count)
        self.logger = logger
    }

    func events(in scope: EventScope) async throws -> [SportEvent] {
        logger.debug(.cache, "Mock events served for scope \(scope)")
        switch scope {
        case .upcoming:
            return fixtures
        case .joined:
            return fixtures.enumerated()
                .filter { $0.offset % Self.joinedStride == 0 }
                .map(\.element)
        }
    }
}

nonisolated enum MockEventFixtures {
    private static let firstEventHoursAhead = 3
    private static let hoursBetweenEvents = 7
    private static let secondsPerHour: TimeInterval = 3600

    private static let templates: [(title: String, sport: SportType, location: String, capacity: Int, host: String)] = [
        ("Sunset 5-a-side", .football, "Riverside Pitch 2", 10, "Marta"),
        ("Pickup at the Cage", .basketball, "Westside Courts", 8, "Dev"),
        ("Doubles, all levels", .tennis, "Park Tennis Club", 4, "Ines"),
        ("Padel after work", .padel, "Padel Hub North", 4, "Tom"),
        ("Easy 8k loop", .running, "Canal Path", 12, "Aiko"),
        ("Beach volley social", .volleyball, "City Beach", 12, "Luca"),
        ("Hills ride", .cycling, "Old Mill Car Park", 15, "Sam"),
        ("Bouldering intro", .climbing, "Crux Climbing", 6, "Noor"),
    ]

    static func make(now: Date, count: Int) -> [SportEvent] {
        (0..<count).map { index in
            let template = templates[index % templates.count]
            let hoursAhead = TimeInterval(firstEventHoursAhead + index * hoursBetweenEvents)
            return SportEvent(
                id: "mock-event-\(index)",
                title: template.title,
                sport: template.sport,
                startsAt: now.addingTimeInterval(hoursAhead * secondsPerHour),
                locationName: template.location,
                capacity: template.capacity,
                participantCount: min(template.capacity, (index * 3) % (template.capacity + 1)),
                hostName: template.host
            )
        }
    }
}
