import Foundation

/// The events standing on one spot of the map, drawn as one pin: two games at the same venue (often one typed name
/// geocoded twice) overlapped pixel for pixel, and the one behind could never be selected. Selecting the stack shows
/// every member's card.
nonisolated struct EventMapStack: Identifiable, Equatable, Sendable {
    /// The first spot rounded to `AppConfig.Events.mapStackDecimals`, so the same spot keeps the same identity across
    /// reloads; a second stack whose first spot rounds the same way takes its first event's id after it.
    let id: String
    let coordinate: Coordinate
    let events: [SportEvent]

    /// What the pin is labelled with: the event's title, or the shared place once there are several.
    var title: String { events.count == 1 ? events[0].title : events[0].locationName }

    /// Puts each event in the first stack whose first spot lies within `AppConfig.Events.mapStackRadiusMeters`, else
    /// opens a new one, keeping the feed's order between stacks and within one. A distance, not a rounded grid, so two
    /// spots centimetres apart on either side of a rounding boundary still share one pin.
    static func stacks(of events: [SportEvent]) -> [EventMapStack] {
        var anchors: [Coordinate] = []
        var groups: [[SportEvent]] = []
        for event in events {
            let spot = event.location.coordinate
            if let index = anchors.firstIndex(where: { $0.distance(to: spot) <= AppConfig.Events.mapStackRadiusMeters }) {
                groups[index].append(event)
            } else {
                anchors.append(spot)
                groups.append([event])
            }
        }
        var usedIDs = Set<String>()
        return groups.map { members in
            var id = key(for: members[0].location.coordinate)
            if usedIDs.contains(id) { id += ":\(members[0].id)" }
            usedIDs.insert(id)
            return EventMapStack(id: id, coordinate: members[0].location.coordinate, events: members)
        }
    }

    private static func key(for coordinate: Coordinate) -> String {
        String(format: "%.\(AppConfig.Events.mapStackDecimals)f:%.\(AppConfig.Events.mapStackDecimals)f",
               coordinate.latitude,
               coordinate.longitude)
    }
}
