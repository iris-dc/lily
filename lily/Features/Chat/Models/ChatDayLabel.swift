import Foundation

/// What a day separator says ("Today", "Yesterday", or the abbreviated date) and the id of its row (`rowID(for:)`), shared
/// with the inbox timeline. Pure, so the rules are tested without a view.
nonisolated enum ChatDayLabel {
    static func text(for day: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return AppBranding.Chat.today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return AppBranding.Chat.yesterday
        }
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: AppLocale.locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return day.formatted(style)
    }

    /// The day chip's row id, shared by the chat and inbox timelines so a day is one row in either list.
    static func rowID(for day: Date) -> String {
        "day-\(Int(day.timeIntervalSince1970))"
    }
}
