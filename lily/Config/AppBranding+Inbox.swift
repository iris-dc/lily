import Foundation

nonisolated extension AppBranding {
    /// Tab title, doubling as the navigation title of the Chats root.
    static let chatsTitle = "Chats"

    /// The Chats tab: the inbox row, the caller's rooms and the states around them.
    enum Chats {
        static let noRooms = "No group chats yet. Join a group to start one."
        static let noRoomsAction = "Explore"
        static let guestMessage = "Sign in to see your chats, invites and game reminders."
        /// What the Chats tab's badge means to assistive technology (the badge itself is not exposed).
        static let oneUnreadChat = "1 unread chat"
        static let unreadChatsFormat = "%ld unread chats"

        static func unreadChats(_ count: Int) -> String {
            count == 1 ? oneUnreadChat : String(format: unreadChatsFormat, count)
        }
    }

    /// The inbox conversation: invites with Accept / Decline, game reminders that open the game.
    enum Inbox {
        static let title = AppBranding.name
        /// Caption of the Chats row while the inbox is empty.
        static let emptyCaption = "Invites and game reminders"
        /// `%@` inviter, `%@` group; the row draws both names in bold.
        static let invitedYouFormat = "%@ invited you to %@"
        static let accept = "Accept"
        static let decline = "Decline"
        static let joined = "You joined"
        static let declined = "Declined"
        static let expired = "Expired"
        static let reminderTitle = "Game reminder"
        /// VoiceOver name of the reminder card's chevron.
        static let openGame = "Open game"
        static let emptyTitle = "Nothing here yet"
        static let emptyMessage = "Invites and reminders for your games show up here."
        static let loadFailedTitle = "Couldn't load your notifications"
        static let loadEarlier = "Load earlier"
        /// `%@` the day as the chat's day chips name it ("Today"), `%@` the clock time; the reminder card puts how far
        /// off the start is after them ("Today, 6:30 PM · in 1 hour").
        static let dayAndTimeFormat = "%@, %@"

        static func invitedYou(inviter: String, group: String) -> String {
            String(format: invitedYouFormat, inviter, group)
        }

        static func dayAndTime(day: String, time: String) -> String {
            String(format: dayAndTimeFormat, day, time)
        }
    }
}
