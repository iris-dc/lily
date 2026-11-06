import Foundation

nonisolated extension AppBranding.Events {
    /// The header of the map's many-events list, beside the place's name.
    static func eventsHere(_ count: Int) -> String {
        localized("\(count) events here")
    }

    /// The pill under the map's card list while that many cards wait below the visible ones.
    static func moreBelow(_ count: Int) -> String {
        localized("+\(count) more")
    }
}
