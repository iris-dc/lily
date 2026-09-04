import Foundation

nonisolated struct SportEvent: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let sport: SportType
    let startsAt: Date
    let locationName: String
    let capacity: Int
    let participantCount: Int
    let hostName: String

    var spotsLeft: Int { max(capacity - participantCount, 0) }
    var isFull: Bool { spotsLeft == 0 }
    var fillRatio: Double { capacity > 0 ? Double(participantCount) / Double(capacity) : 0 }
}

/// Which slice of events a list shows.
nonisolated enum EventScope: Hashable, Sendable {
    case upcoming
    case joined
}
