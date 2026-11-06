import Foundation

/// The events standing on one spot of the map, drawn as one pin: two games at the same venue (often one typed name
/// geocoded twice) overlapped pixel for pixel, and the one behind could never be selected. Selecting the stack shows
/// every member's card.
nonisolated struct EventMapStack: Identifiable, Equatable, Sendable {
    /// The rounded coordinate, so the same spot keeps the same identity across reloads.
    let id: String
    let coordinate: Coordinate
    let events: [SportEvent]

    /// What the pin is labelled with: the event's title, or the shared place once there are several.
    var title: String { events.count == 1 ? events[0].title : events[0].locationName }

    /// Groups by coordinate rounded to `AppConfig.Events.mapStackDecimals` (about 11 m), keeping the feed's order
    /// between stacks and within one.
    static func stacks(of events: [SportEvent]) -> [EventMapStack] {
        var order: [String] = []
        var groups: [String: [SportEvent]] = [:]
        for event in events {
            let key = key(for: event.location.coordinate)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(event)
        }
        return order.compactMap { key in
            guard let members = groups[key] else { return nil }
            return EventMapStack(id: key, coordinate: members[0].location.coordinate, events: members)
        }
    }

    private static func key(for coordinate: Coordinate) -> String {
        String(format: "%.\(AppConfig.Events.mapStackDecimals)f:%.\(AppConfig.Events.mapStackDecimals)f",
               coordinate.latitude,
               coordinate.longitude)
    }
}
