import Foundation

nonisolated extension InboxItem {
    /// One line for the Chats row: "Noor invited you to Climbing Buddies", "Game reminder · Sunset 5-a-side",
    /// "Match reminder · Tuesday Table Tennis"; `nil` for a kind this build cannot draw.
    var caption: String? {
        switch kind {
        case .groupInvite:
            invite.map { AppBranding.Inbox.invitedYou(inviter: $0.inviterName, group: $0.groupName) }
        case .eventReminder:
            reminder.map { AppBranding.Groups.caption([AppBranding.Inbox.reminderTitle, $0.title]) }
        case .tournamentInvite:
            tournamentInvite.map { AppBranding.Inbox.invitedYou(inviter: $0.inviterName, group: $0.tournamentName) }
        case .matchReminder:
            matchReminder.map { AppBranding.Groups.caption([AppBranding.Inbox.matchReminderTitle, $0.tournamentName]) }
        case .unknown:
            nil
        }
    }
}

/// When something starts, for a reminder card: the day as the chat's day chips name it, the clock time in the app's
/// short time style, then how far off it is ("Today, 6:30 PM · in 1 hour"), so the reader has the time and the
/// countdown in one line. The clock time follows the calendar's zone and the calendar's locale when it has one (so a
/// test can pin it), else the app's language.
nonisolated enum InboxTimeCaption {
    static func text(for date: Date, now: Date, calendar: Calendar) -> String {
        let locale = calendar.locale ?? AppLocale.locale
        let timeStyle = Date.FormatStyle(date: .omitted,
                                         time: .shortened,
                                         locale: locale,
                                         calendar: calendar,
                                         timeZone: calendar.timeZone)
        let day = ChatDayLabel.text(for: date, now: now, calendar: calendar)
        let dayAndTime = AppBranding.Inbox.dayAndTime(day: day, time: date.formatted(timeStyle))
        let distance = date.formatted(.relative(presentation: .named).locale(locale))
        return AppBranding.Groups.caption([dayAndTime, distance])
    }
}

nonisolated extension ReminderPayload {
    func startsAtCaption(now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        InboxTimeCaption.text(for: startsAt, now: now, calendar: calendar)
    }
}

nonisolated extension MatchReminderPayload {
    func startsAtCaption(now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        InboxTimeCaption.text(for: scheduledAt, now: now, calendar: calendar)
    }
}
