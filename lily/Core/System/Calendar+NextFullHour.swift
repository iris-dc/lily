import Foundation

nonisolated extension Calendar {
    /// The first full hour at or after `date` in this calendar's zone: a date exactly on the hour is kept, anything past
    /// it rounds up to the next.
    func nextFullHour(after date: Date) -> Date {
        guard let hour = dateInterval(of: .hour, for: date) else { return date }
        return hour.start == date ? date : hour.end
    }
}
