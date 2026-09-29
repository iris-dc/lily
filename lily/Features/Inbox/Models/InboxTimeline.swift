import Foundation

/// One row of the inbox list, ready to draw.
nonisolated enum InboxTimelineRow: Identifiable, Hashable, Sendable {
    /// A day boundary between items.
    case day(Date)
    case item(InboxItem)

    var id: String {
        switch self {
        case .day(let date): "day-\(Int(date.timeIntervalSince1970))"
        case .item(let item): item.id
        }
    }
}

/// Turns the store's items into rows: kinds this build cannot draw are hidden, and a day chip precedes the first item
/// of each day, as in a chat. Pure, so the rule is tested without a view.
nonisolated enum InboxTimeline {
    static func rows(_ items: [InboxItem], calendar: Calendar = .autoupdatingCurrent) -> [InboxTimelineRow] {
        var rows: [InboxTimelineRow] = []
        var previousDay: Date?
        for item in items where item.isVisible {
            let day = calendar.startOfDay(for: item.createdAt)
            if previousDay != day {
                rows.append(.day(day))
                previousDay = day
            }
            rows.append(.item(item))
        }
        return rows
    }
}
