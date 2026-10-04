import Foundation

/// Copy of a tournament's invites, its report, the organiser's match schedule and the outcome lines of a finished
/// tournament. An extension file because `AppBranding.Tournaments` is at the type-body limit.
nonisolated extension AppBranding.Tournaments {
    /// The menu item; the sheet it opens is the groups' report sheet with this title.
    static var report: String { localized("Report tournament") }
    /// Under the title once the tournament is over.
    static var cancelledNotice: String { localized("This tournament was cancelled.") }

    static func winner(_ name: String) -> String {
        localized("Winner: \(name)")
    }

    /// The tournament invite card's detail line: "Football · Single elimination · Teams of 5".
    static func inviteDetails(type: EventType, format: TournamentFormat, teamSize: Int) -> String {
        AppBranding.Groups.caption([type.displayName, format.displayName, Create.teamSize(teamSize)])
    }

    /// The organiser's time and place for one match, from the match sheet.
    enum Schedule {
        /// The link on the match sheet and the screen's title.
        static var title: String { localized("Schedule match") }
        /// The time section's header; the row inside it is `time`.
        static var when: String { AppBranding.Events.Create.startsAt }
        static var time: String { localized("Time") }
        static var place: String { AppBranding.Events.Create.whereSection }
        static var placePlaceholder: String { AppBranding.Events.Create.locationNamePlaceholder }
        static var pickOnMap: String { AppBranding.Events.Create.pickOnMap }
        static var save: String { AppBranding.Groups.Create.save }
        /// Removes the time and the place; shown only while the match has either.
        static var clear: String { localized("Clear schedule") }
        /// Under the place field: the tournament's spot stands unless another is picked.
        static var placeFooter: String { localized("Leave the place empty to set the time alone.") }
    }
}
