import Foundation

nonisolated extension AppConfig {
    /// Groups: limits mirrored from the backend's request constraints, list behaviour and the invite code format.
    enum Groups {
        static let nameLength = 3...60
        static let descriptionMaxLength = 500
        static let maxMembers = 500
        static let maxMemberships = 50
        static let discoverPageSize = 50
        static let searchDebounce: Duration = .milliseconds(300)
        static let queryMaxLength = 40
        /// A reappearing Mine list reuses groups loaded more recently than this; pull-to-refresh always reloads.
        static let listStaleAfter: TimeInterval = 60
        static let retryAfterFailure: TimeInterval = 10
        /// Invite codes: Crockford base32 (no `I`, `L`, `O`, `U`), shown in groups of four.
        static let inviteCodeLength = 12
        static let inviteCodeAlphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
        static let inviteCodePattern = "^[0-9A-HJKMNP-TV-Z]{12}$"
        static let inviteCodeGroupSize = 4
        static let inviteExpiryChoicesDays = [1, 7, 30]
        static let inviteDefaultDays = 7
        /// `0` is unlimited.
        static let inviteUseChoices = [0, 1, 10]
        /// The pre-selected use limit; 0 is unlimited.
        static let inviteDefaultUses = 0
        /// The code the mock invite repository accepts; canonical, so it round-trips through normalisation unchanged.
        static let mockInviteCode = "KRZB7K3MQX9P"
        static let mockGroupCount = 6
        /// Where the backend's invite links point (`<base>/<code>`); the mock builds its links from it.
        static let inviteLinkBaseURL = AppConfig.API.productionBaseURL.appending(path: "invite")
    }
}

nonisolated extension AppConfig.API.Paths {
    static let groups = "/api/groups"
    static let invitePreview = "/api/invites/preview"
    static let inviteRedeem = "/api/invites/redeem"

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

    static func groupInvites(id: String) -> String {
        "\(group(id: id))/invites"
    }

    static func groupInvite(id: String, inviteID: String) -> String {
        "\(groupInvites(id: id))/\(inviteID)"
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
    /// Takes the next argument as the invite code to preview at launch, as a universal link would.
    static let openInvite = "-open-invite"
    /// Takes the next argument as the user id of every mock sign-in, so two simulators can act as two users.
    static let mockUserID = "-mock-user-id"
}
