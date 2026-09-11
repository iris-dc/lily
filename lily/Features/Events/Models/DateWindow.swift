import Foundation

/// Inclusive range of whole days, as chosen in the filter.
nonisolated struct DateWindow: Hashable, Sendable {
    /// Start of the first day.
    var start: Date
    /// End of the last day.
    var end: Date

    func contains(_ date: Date) -> Bool { start <= date && date <= end }

    /// The whole days from `first` to `last` inclusive; a `last` before `first` collapses to the single day `first`.
    static func days(from first: Date, to last: Date, calendar: Calendar = .current) -> DateWindow {
        let start = calendar.startOfDay(for: first)
        let lastDay = max(calendar.startOfDay(for: last), start)
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: lastDay) ?? lastDay
        return DateWindow(start: start, end: end)
    }

    /// The default proposal when dates are switched on: today plus the configured span.
    static func proposal(from today: Date = .now, calendar: Calendar = .current) -> DateWindow {
        let last = calendar.date(byAdding: .day, value: AppConfig.Events.defaultFilterDateSpanDays, to: today) ?? today
        return days(from: today, to: last, calendar: calendar)
    }
}
