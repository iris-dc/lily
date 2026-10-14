import Foundation
import Testing
@testable import lily

/// The reminder cards' time line ("Today, 12:00 · in 1 hour"), pinned on a fixed `now` over a UTC, 24-hour calendar:
/// the day as the chat's chips name it, the clock time, and a countdown judged against the given `now`, never the
/// wall clock.
@MainActor
struct InboxTimeCaptionTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()
    /// 2026-03-10 11:00 UTC.
    private static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 11))!

    private func caption(for game: Date, now: Date) -> String {
        InboxTimeCaption.text(for: game, now: now, calendar: Self.calendar)
    }

    @Test func theCountdownFollowsTheGivenNow() {
        let game = Self.now.addingTimeInterval(3_600)

        #expect(caption(for: game, now: Self.now) == "Today, 12:00 · in 1 hour")
        #expect(caption(for: game, now: Self.now.addingTimeInterval(3 * 3_600)) == "Today, 12:00 · 2 hours ago")
    }

    @Test func aGameOfYesterdayReadsYesterdayInBothParts() {
        let game = Self.now.addingTimeInterval(-25 * 3_600)

        #expect(caption(for: game, now: Self.now) == "Yesterday, 10:00 · yesterday")
    }

    @Test func aFartherGameNamesTheDateAndCountsTheDays() {
        let game = Self.now.addingTimeInterval(3 * 86_400)
        let day = ChatDayLabel.text(for: game, now: Self.now, calendar: Self.calendar)

        let expected = AppBranding.Groups.caption([AppBranding.Inbox.dayAndTime(day: day, time: "11:00"), "in 3 days"])
        #expect(caption(for: game, now: Self.now) == expected)
    }
}
