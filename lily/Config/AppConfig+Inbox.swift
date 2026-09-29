import Foundation

nonisolated extension AppConfig {
    /// The inbox: the pinned system conversation of invites and game reminders on the Chats tab.
    enum Inbox {
        /// Items per page, the backend's maximum.
        static let pageSize = 50
        /// A reappearing inbox reuses items loaded more recently than this; pull-to-refresh always reloads.
        static let listStaleAfter: TimeInterval = 60
        static let retryAfterFailure: TimeInterval = 10
        /// The mock invite expires this long after the launch: seven days, the backend's `invites.pending-days`.
        static let mockInviteExpiry: TimeInterval = 7 * 24 * 60 * 60
        /// The mock reminder names a game starting this far ahead, the backend's `reminders.lead`.
        static let mockReminderLead: TimeInterval = 60 * 60
    }
}

nonisolated extension AppConfig.API.Paths {
    static let inbox = "/api/me/inbox"
    static let inboxRead = "/api/me/inbox/read"

    static func inboxAccept(id: String) -> String {
        "\(inbox)/\(id)/accept"
    }

    static func inboxDecline(id: String) -> String {
        "\(inbox)/\(id)/decline"
    }
}
