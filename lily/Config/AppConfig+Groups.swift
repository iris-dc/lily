import Foundation

nonisolated extension AppConfig {
    /// Groups: limits mirrored from the backend's request constraints and list behaviour.
    enum Groups {
        static let nameLength = 3...60
        static let descriptionMaxLength = 500
        /// The group's place name, the backend's `LocationDto` limit (the event form's too).
        static let locationNameMaxLength = AppConfig.Events.Creation.locationNameMaxLength
        static let maxMembers = 500
        static let maxMemberships = 50
        static let discoverPageSize = 50
        static let searchDebounce: Duration = .milliseconds(300)
        static let queryMaxLength = 40
        /// A reappearing Mine list reuses groups loaded more recently than this; pull-to-refresh always reloads.
        static let listStaleAfter: TimeInterval = 60
        static let retryAfterFailure: TimeInterval = 10
        /// The fixture communities; the fixtures add one direct conversation (with Marta) on top.
        static let mockGroupCount = 6
    }
}

nonisolated extension AppConfig.API.Paths {
    static let groups = "/api/groups"

    static func group(id: String) -> String {
        "\(groups)/\(id)"
    }

    static func groupMembers(id: String) -> String {
        "\(group(id: id))/members"
    }

    static func groupMember(id: String, userID: String) -> String {
        "\(groupMembers(id: id))/\(userID)"
    }

    static func groupBans(id: String) -> String {
        "\(group(id: id))/bans"
    }

    static func groupBan(id: String, userID: String) -> String {
        "\(groupBans(id: id))/\(userID)"
    }

    /// `POST` sends a direct invite into the group; the invitee answers it from their inbox.
    static func groupInvites(id: String) -> String {
        "\(group(id: id))/invites"
    }

    /// `GET` lists the people the caller may invite into the group.
    static func groupInvitees(id: String) -> String {
        "\(group(id: id))/invitees"
    }

    static func groupEvents(id: String) -> String {
        "\(group(id: id))/events"
    }
}

nonisolated extension AppConfig.API.Query {
    static let query = "q"
    static let type = "type"
    static let cursor = "cursor"
    static let limit = "limit"
}

nonisolated extension AppConfig.LaunchArguments {
    /// Takes the next argument as the user id of every mock sign-in, so two simulators can act as two users.
    static let mockUserID = "-mock-user-id"
}
