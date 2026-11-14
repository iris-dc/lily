import Foundation

/// The segmented Home's copy: the picker's segments, the create button per segment, the count line and the
/// empty hints.
nonisolated extension AppBranding.Home {
    /// VoiceOver label of the segmented picker.
    static var segmentPicker: String { localized("Section") }

    static var eventsSegment: String { localized("Events") }
    static var tournamentsSegment: String { localized("Tournaments") }
    static var groupsSegment: String { localized("Groups") }

    static var createEvent: String { localized("Create an event") }
    static var createTournament: String { localized("Create a tournament") }
    static var createGroup: String { localized("Create a group") }

    static var noEventsTitle: String { localized("No events yet") }
    static var noTournamentsTitle: String { localized("No tournaments yet") }
    static var noGroupsTitle: String { localized("No groups yet") }
    static var noTournaments: String { localized("Tournaments you enter or organise will appear here.") }
    static var findGroups: String { localized("Find a group on Explore, or create your own.") }

    static func eventCount(_ count: Int) -> String {
        localized("\(count) events")
    }

    static func tournamentCount(_ count: Int) -> String {
        localized("\(count) tournaments")
    }

    static func groupCount(_ count: Int) -> String {
        localized("\(count) groups")
    }
}
