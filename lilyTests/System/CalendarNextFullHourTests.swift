import Foundation
import Testing
@testable import lily

/// `nextFullHour(after:)` keeps a date on the hour and rounds anything past it up to the next full hour of the
/// calendar's own zone, so a half-hour zone rounds to its hours and not to UTC's.
@MainActor
struct CalendarNextFullHourTests {
    /// 2027-01-15 08:00:00 UTC exactly (500,000 hours since the epoch), which is 13:30 in Kolkata.
    private let onTheHour = Date(timeIntervalSince1970: 1_800_000_000)
    private let utc = makeCalendar(zone: "UTC")
    private let kolkata = makeCalendar(zone: "Asia/Kolkata")

    @Test func aDatePastTheHourRoundsUpToTheNextOne() {
        let pastTheHour = onTheHour.addingTimeInterval(25 * 60 + 7)

        #expect(utc.nextFullHour(after: pastTheHour) == onTheHour.addingTimeInterval(3_600))
    }

    @Test func aDateOnTheHourIsKept() {
        #expect(utc.nextFullHour(after: onTheHour) == onTheHour)
    }

    @Test func aSecondPastTheHourRoundsUp() {
        #expect(utc.nextFullHour(after: onTheHour.addingTimeInterval(1)) == onTheHour.addingTimeInterval(3_600))
    }

    /// 08:15 UTC is 13:45 in Kolkata (UTC+05:30), whose next full hour is 14:00 IST, that is 08:30 UTC; the same
    /// instant rounds to 09:00 in a UTC calendar.
    @Test func aHalfHourZoneRoundsToItsOwnFullHour() {
        let quarterPast = onTheHour.addingTimeInterval(15 * 60)

        #expect(kolkata.nextFullHour(after: quarterPast) == onTheHour.addingTimeInterval(30 * 60))
        #expect(utc.nextFullHour(after: quarterPast) == onTheHour.addingTimeInterval(3_600))
    }

    /// Whether a date is "on the hour" is the calendar's call too: 08:00 UTC is half past one in Kolkata and rounds
    /// up to 14:00 IST there.
    @Test func anHourOfOneZoneIsHalfPastInAnotherAndRoundsThere() {
        #expect(kolkata.nextFullHour(after: onTheHour) == onTheHour.addingTimeInterval(30 * 60))
    }
}

private func makeCalendar(zone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}
