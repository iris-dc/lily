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
    private struct Template {
        let title: String
        let sport: SportType
        let location: String
        let capacity: Int
        let host: String
        /// Offset from the demo centre as a fraction of `AppConfig.Location.fixtureSpreadDegrees`.
        let offset: (lat: Double, lon: Double)
    }

    private static let templates: [Template] = [
        Template(
            title: "Sunset 5-a-side",
            sport: .football,
            location: "Riverside Pitch 2",
            capacity: 10,
            host: "Marta",
            offset: (0.3, -0.6)
        ),
        Template(
            title: "Pickup at the Cage",
            sport: .basketball,
            location: "Westside Courts",
            capacity: 8,
            host: "Dev",
            offset: (-0.5, -0.9)
        ),
        Template(
            title: "Doubles, all levels",
            sport: .tennis,
            location: "Park Tennis Club",
            capacity: 4,
            host: "Ines",
            offset: (0.8, 0.4)
        ),
        Template(
            title: "Padel after work",
            sport: .padel,
            location: "Padel Hub North",
            capacity: 4,
            host: "Tom",
            offset: (1.0, -0.2)
        ),
        Template(
            title: "Easy 8k loop",
            sport: .running,
            location: "Canal Path",
            capacity: 12,
            host: "Aiko",
            offset: (-0.2, 0.7)
        ),
        Template(
            title: "Beach volley social",
            sport: .volleyball,
            location: "City Beach",
            capacity: 12,
            host: "Luca",
            offset: (-0.9, 0.3)
        ),
        Template(
            title: "Hills ride",
            sport: .cycling,
            location: "Old Mill Car Park",
            capacity: 15,
            host: "Sam",
            offset: (0.5, 1.0)
        ),
        Template(
            title: "Bouldering intro",
            sport: .climbing,
            location: "Crux Climbing",
            capacity: 6,
            host: "Noor",
            offset: (-0.7, -0.3)
        ),
    ]

    /// Hours until the first fixture starts, and the gap between consecutive fixtures.
    private static let firstStartHours = 3.0
    private static let hoursBetweenEvents = 7.0
    private static let secondsPerHour = 3600.0

    static func make(now: Date, count: Int) -> [SportEvent] {
        (0..<count).map { index in
            let template = templates[index % templates.count]
            let hoursAhead = firstStartHours + Double(index) * hoursBetweenEvents
            return SportEvent(
                id: "mock-event-\(index)",
                title: template.title,
                sport: template.sport,
                startsAt: now.addingTimeInterval(hoursAhead * secondsPerHour),
                location: EventLocation(name: template.location, coordinate: coordinate(for: template)),
                capacity: template.capacity,
                participantCount: min(template.capacity, (index * 3) % (template.capacity + 1)),
                hostName: template.host
            )
        }
    }

    private static func coordinate(for template: Template) -> Coordinate {
        let center = AppConfig.Location.mockCenter
        let spread = AppConfig.Location.fixtureSpreadDegrees
        return Coordinate(latitude: center.latitude + template.offset.lat * spread,
                          longitude: center.longitude + template.offset.lon * spread)
    }
}
