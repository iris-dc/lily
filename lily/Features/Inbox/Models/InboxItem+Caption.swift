import Foundation

nonisolated extension InboxItem {
    /// One line for the Chats row: "Noor invited you to Climbing Buddies", "Game reminder · Sunset 5-a-side"; `nil`
    /// for a kind this build cannot draw.
    var caption: String? {
        switch kind {
        case .groupInvite:
            invite.map { AppBranding.Inbox.invitedYou(inviter: $0.inviterName, group: $0.groupName) }
        case .eventReminder:
            reminder.map { AppBranding.Groups.caption([AppBranding.Inbox.reminderTitle, $0.title]) }
        case .unknown:
            nil
        }
    }
}

nonisolated extension InvitePayload {
    /// What an answered or lapsed invite says in place of its buttons; `nil` while it is still open.
    func statusCaption(now: Date) -> String? {
        switch status {
        case .accepted: AppBranding.Inbox.joined
        case .declined: AppBranding.Inbox.declined
        case .pending: expiresAt > now ? nil : AppBranding.Inbox.expired
        }
    }
}

nonisolated extension ReminderPayload {
    /// When the game starts, for the reminder card: the day as the chat's day chips name it, the clock time in the
    /// app's short time style, then how far off it is ("Today, 6:30 PM · in 1 hour"), so the reader has the time and
    /// the countdown in one line. The clock time follows the calendar's zone and the calendar's locale when it has one
    /// (so a test can pin it), else the app's language.
    func startsAtCaption(now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let locale = calendar.locale ?? AppLocale.locale
        let timeStyle = Date.FormatStyle(date: .omitted,
                                         time: .shortened,
                                         locale: locale,
                                         calendar: calendar,
                                         timeZone: calendar.timeZone)
        let day = ChatDayLabel.text(for: startsAt, now: now, calendar: calendar)
        let dayAndTime = AppBranding.Inbox.dayAndTime(day: day, time: startsAt.formatted(timeStyle))
        let distance = startsAt.formatted(.relative(presentation: .named).locale(locale))
        return AppBranding.Groups.caption([dayAndTime, distance])
    }
}
