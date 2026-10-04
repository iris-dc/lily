import Foundation

nonisolated extension AppBranding {
    /// Tab title, doubling as the navigation title of the Chats root.
    static var chatsTitle: String { localized("Chats") }

    /// The Chats tab: the inbox row, the caller's rooms and the states around them.
    enum Chats {
        static var noRooms: String { localized("No group chats yet. Join a group to start one.") }
        static var noRoomsAction: String { localized("Explore") }
        static var guestMessage: String { localized("Sign in to see your chats, invites and game reminders.") }
        /// What the Chats tab's badge means to assistive technology (the badge itself is not exposed).
        static func unreadChats(_ count: Int) -> String {
            localized("\(count) unread chats")
        }
    }

    /// The inbox conversation: invites with Accept / Decline, game reminders that open the game.
    enum Inbox {
        static let title = AppBranding.name
        /// Caption of the Chats row while the inbox is empty.
        static var emptyCaption: String { localized("Invites and game reminders") }
        static var accept: String { localized("Accept") }
        static var decline: String { localized("Decline") }
        static var joined: String { localized("You joined") }
        static var declined: String { localized("Declined") }
        static var expired: String { localized("Expired") }
        static var reminderTitle: String { localized("Game reminder") }
        static var matchReminderTitle: String { localized("Match reminder") }
        /// VoiceOver names of the reminder cards' chevrons.
        static var openGame: String { localized("Open game") }
        static var openTournament: String { localized("Open tournament") }
        static var emptyTitle: String { localized("Nothing here yet") }
        static var emptyMessage: String { localized("Invites and reminders for your games show up here.") }
        static var loadFailedTitle: String { localized("Couldn't load your notifications") }
        static var loadEarlier: String { localized("Load earlier") }
        /// The inviter and the group; the card draws both names in bold through `inviteText(inviter:group:)`.
        static func invitedYou(inviter: String, group: String) -> String {
            localized("\(inviter) invited you to \(group)")
        }

        /// The day as the chat's day chips name it ("Today") and the clock time; the reminder card puts how far off the
        /// start is after them ("Today, 6:30 PM · in 1 hour").
        static func dayAndTime(day: String, time: String) -> String {
            localized("\(day), \(time)")
        }

        /// The match reminder's opponent line.
        static func versus(_ opponent: String) -> String {
            localized("vs \(opponent)")
        }
    }
}
