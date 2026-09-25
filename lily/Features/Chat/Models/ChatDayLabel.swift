import Foundation

/// What a day separator says: "Today", "Yesterday", or the abbreviated date. Pure, so the rule is tested without a view.
nonisolated enum ChatDayLabel {
    static func text(for day: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return AppBranding.Chat.today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return AppBranding.Chat.yesterday
        }
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return day.formatted(style)
    }
}
