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

/// When something starts, for a reminder card: the day as the chat's day chips name it, the clock time in the short
/// style, then how far off it is ("Today, 6:30 PM · in 1 hour"), so the reader has the time and the countdown in one
/// line. Day and countdown are judged against `now`, never the wall clock; the clock time follows the calendar's zone
/// and locale, falling back to the app's language, so the whole line is determined by its inputs.
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
        // The event is the anchor and `now` the input: that way round reads "in 1 hour" for a game an hour ahead.
        let distance = now.formatted(Date.AnchoredRelativeFormatStyle(anchor: date,
                                                                      presentation: .named,
                                                                      unitsStyle: .wide,
                                                                      locale: locale,
                                                                      calendar: calendar))
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
