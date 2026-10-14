import Foundation

nonisolated extension Calendar {
    /// The first full hour at or after `date` in this calendar's zone: a date on the hour is kept, anything past it
    /// rounds up to the next one. Decided here once for the create forms' proposed start and the match schedule's
    /// proposal, which until then skipped a date exactly on the hour.
    func nextFullHour(after date: Date) -> Date {
        guard let hour = dateInterval(of: .hour, for: date) else { return date }
        return hour.start == date ? date : hour.end
    }
}
