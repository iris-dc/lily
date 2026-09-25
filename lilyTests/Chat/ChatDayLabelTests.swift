import Foundation
import Testing
@testable import lily

struct ChatDayLabelTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()
    /// 2027-01-15 12:00 UTC.
    private static let now = Date(timeIntervalSince1970: 1_800_014_400)

    private func label(daysAgo: Int, hour: Int = 9) -> String {
        let day = Self.calendar.date(byAdding: .day, value: -daysAgo, to: Self.now)!
        let dated = Self.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return ChatDayLabel.text(for: dated, now: Self.now, calendar: Self.calendar)
    }

    @Test func todayAndYesterdayAreNamedWhateverTheHour() {
        #expect(label(daysAgo: 0) == "Today" && label(daysAgo: 0, hour: 23) == "Today")
        #expect(label(daysAgo: 1) == "Yesterday" && label(daysAgo: 1, hour: 0) == "Yesterday")
    }

    @Test func olderDaysShowTheAbbreviatedDate() {
        #expect(label(daysAgo: 2) == "Jan 13, 2027")
        #expect(label(daysAgo: 40) == "Dec 6, 2026")
    }
}
