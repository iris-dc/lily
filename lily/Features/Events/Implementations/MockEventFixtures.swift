import Foundation

/// The fixture events of a mock run: templates scattered around `AppConfig.Location.mockCenter`, their timing and
/// `make(now:count:)`; the participant names live in `MockEventFixtures+Participants`.
nonisolated enum MockEventFixtures {
    private struct Template {
        let title: String
        let type: EventType
        let location: String
        /// `nil` for a game without a limit.
        let capacity: Int?
        /// Fixed per template so the feed shows every capacity state: empty-ish, half, nearly full (amber), full, and
        /// (with `allowsExtraParticipants`) short of and past the number needed.
        let participants: Int
        var allowsExtraParticipants = false
        let host: String
        /// Offset from the demo centre as a fraction of `AppConfig.Location.fixtureSpreadDegrees`.
        let offset: (lat: Double, lon: Double)
        /// Optional details, left out on some templates so every surface is seen with and without them.
        var description: String?
        var lookingFor: String?
        var skillLevel: SkillLevel?
        var priceAmount: Decimal?
        /// The group the game is hosted in; two fixtures carry one so the badge and "Hosted in" have data. The private
        /// group's game is off Explore, as on the backend, and reached through its group's Events segment.
        var group: EventGroupRef?
    }

    private static let templates: [Template] = [
        Template(
            title: "Sunset 5-a-side",
            type: .football,
            location: "Riverside Pitch 2",
            capacity: 10,
            participants: 6,
            host: "Marta",
            offset: (0.3, -0.6),
            description: "Friendly 5-a-side on the small pitch by the river. Teams are split on the spot; two 25-minute halves.",
            lookingFor: "Two more players, ideally one who likes to keep goal.",
            skillLevel: .intermediate,
            priceAmount: 5,
            group: MockGroupFixtures.ref(for: MockGroupFixtures.kickersID)
        ),
        Template(
            title: "Pickup at the Cage",
            type: .basketball,
            location: "Westside Courts",
            capacity: 8,
            participants: 8,
            host: "Dev",
            offset: (-0.5, -0.9),
            description: "Half-court pickup under the lights. Winners stay on.",
            skillLevel: .beginner
        ),
        Template(
            title: "Doubles, all levels",
            type: .tennis,
            location: "Park Tennis Club",
            capacity: 4,
            participants: 1,
            host: "Ines",
            offset: (0.8, 0.4),
            lookingFor: "One more doubles partner who can serve and volley.",
            priceAmount: 12
        ),
        Template(
            title: "Padel after work",
            type: .padel,
            location: "Padel Hub North",
            capacity: 4,
            participants: 4,
            host: "Tom",
            offset: (1.0, -0.2),
            description: "Court booked from six. Rackets available to borrow.",
            priceAmount: 7.5,
            group: MockGroupFixtures.ref(for: MockGroupFixtures.padelID)
        ),
        Template(
            title: "Easy 8k loop",
            type: .running,
            location: "Canal Path",
            capacity: nil,
            participants: 5,
            host: "Aiko",
            offset: (-0.2, 0.7),
            description: "Conversational pace along the canal, about 8 km. Nobody gets dropped.",
            lookingFor: "Anyone who wants company on an easy run.",
            skillLevel: .beginner
        ),
        Template(
            title: "Beach volley social",
            type: .volleyball,
            location: "City Beach",
            capacity: 12,
            participants: 9,
            host: "Luca",
            offset: (-0.9, 0.3),
            lookingFor: "Three more to fill two courts; mixed teams."
        ),
        Template(
            title: "Hills ride",
            type: .cycling,
            location: "Old Mill Car Park",
            capacity: 15,
            participants: 3,
            allowsExtraParticipants: true,
            host: "Sam",
            offset: (0.5, 1.0),
            description: "60 km with two proper climbs. Bring lights for the way back.",
            skillLevel: .advanced
        ),
        Template(
            title: "Bouldering intro",
            type: .climbing,
            location: "Crux Climbing",
            capacity: 4,
            participants: 6,
            allowsExtraParticipants: true,
            host: "Noor",
            offset: (-0.7, -0.3)
        ),
        Template(
            title: "Sunrise yoga",
            type: .yoga,
            location: "Tempelhofer Feld",
            capacity: 20,
            participants: 11,
            host: "Priya",
            offset: (-1.0, 0.1),
            description: "Mats on the grass, an hour of slow flow. Bring your own mat and a warm layer.",
            skillLevel: .beginner
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
                type: template.type,
                startsAt: now.addingTimeInterval(hoursAhead * secondsPerHour),
                location: EventLocation(name: template.location, coordinate: coordinate(for: template)),
                capacity: template.capacity,
                allowsExtraParticipants: template.allowsExtraParticipants,
                participantCount: template.participants,
                hostName: template.host,
                description: template.description,
                lookingFor: template.lookingFor,
                skillLevel: template.skillLevel,
                price: template.priceAmount.map { Price(amount: $0, currencyCode: AppConfig.Currency.defaultCode) },
                group: template.group
            )
        }
    }

    private static func coordinate(for template: Template) -> Coordinate {
        .aroundMockCenter(lat: template.offset.lat, lon: template.offset.lon)
    }
}
