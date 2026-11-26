import Foundation

/// The backend's `EventSummary`: a game as a profile's "Games together" row shows it. The summary is not the whole
/// event; Activity's rows fetch the detail by id (`EventDestination`), a profile's stay rows alone.
nonisolated struct EventSummary: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let type: EventType
    let startsAt: Date
    let locationName: String

    init(id: String, title: String, type: EventType, startsAt: Date, locationName: String) {
        self.id = id
        self.title = title
        self.type = type
        self.startsAt = startsAt
        self.locationName = locationName
    }

    /// An event the caller holds in full, reduced to its summary (the mock profiles).
    init(_ event: SportEvent) {
        self.init(id: event.id, title: event.title, type: event.type, startsAt: event.startsAt, locationName: event.locationName)
    }

    /// "Football · 2 Oct 2026 · Tempelhofer Feld".
    var caption: String {
        AppBranding.Groups.caption([type.displayName, startsAt.formatted(LilyTheme.DateStyles.date), locationName])
    }

    /// The caption led by the "Ended" marker, for Activity's rows: every game there is history.
    var endedCaption: String {
        AppBranding.Groups.caption([AppBranding.Events.ended, type.displayName,
                                    startsAt.formatted(LilyTheme.DateStyles.date), locationName])
    }
}
