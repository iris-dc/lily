import Foundation
import Testing
@testable import lily

struct EventFilterTests {
    private let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize)
    private let center = AppConfig.Location.mockCenter

    private func matching(_ filter: EventFilter, from origin: Coordinate? = nil) -> [SportEvent] {
        events.filter { filter.matches($0, from: origin) }
    }

    private func matches(_ filter: EventFilter, _ event: SportEvent) -> Bool {
        filter.matches(event, from: nil)
    }

    /// A start at the given hour today, in the calendar the filter judges with.
    private func start(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 30, second: 0, of: .now)!
    }

    @Test func defaultFilterLimitsDistanceOnlyAndCountsAsInactive() {
        let filter = EventFilter()
        #expect(!filter.isActive)
        #expect(filter.maxDistanceMeters == AppConfig.Events.defaultFilterRadiusMeters)
        #expect(matching(filter, from: center) == events, "every fixture lies within the default radius")
        #expect(matching(filter) == events)
    }

    @Test func anywhereIsAChoiceAwayFromTheDefault() {
        var filter = EventFilter()
        filter.maxDistanceMeters = nil
        #expect(filter.isActive)
        #expect(matching(filter, from: center) == events)
    }

    @Test func selectedTypesNarrowTheMatches() {
        var filter = EventFilter()
        filter.toggle(.tennis)
        filter.toggle(.padel)
        #expect(filter.isActive)
        #expect(filter.includes(.tennis) && filter.includes(.padel) && !filter.includes(.football))
        #expect(matching(filter).map(\.type).sorted { $0.wireName < $1.wireName } == [.padel, .tennis])
    }

    @Test func yogaAndOtherAreFilterableTypes() {
        var filter = EventFilter()
        filter.toggle(.yoga)
        #expect(matching(filter).map(\.title) == ["Sunrise yoga"])
        #expect(EventType.yoga.displayName == "Yoga")
        filter.toggle(.yoga)
        filter.toggle(.other)
        #expect(matching(filter).isEmpty, "no fixture is typed other any more")
        #expect(EventType.other.displayName == "Other")
    }

    /// A type this build does not know draws as Other, but for the filter it is nobody's choice: no selection is no
    /// criterion, and any selection, Other's included, leaves such a game out.
    @Test func aFilterNeverMatchesAnUnknownType() {
        let cricket = SportEvent.fixture(type: .unknown("cricket"))
        var filter = EventFilter()
        #expect(matches(filter, cricket), "no type selected is no criterion")

        filter.toggle(.tennis)
        #expect(!matches(filter, cricket))

        filter.toggle(.tennis)
        filter.toggle(.other)
        #expect(!matches(filter, cricket), "an unknown type draws as Other but is not Other for the filter")
        #expect(!filter.includes(.unknown("cricket")))
    }

    @Test func togglingTwiceRemovesTheType() {
        var filter = EventFilter()
        filter.toggle(.running)
        filter.toggle(.running)
        #expect(!filter.isActive)
    }

    @Test func distanceNeedsAnOriginAndIsSkippedWithoutOne() {
        var filter = EventFilter()
        filter.maxDistanceMeters = 1
        #expect(matching(filter, from: nil) == events, "unknown position must not hide everything")
        #expect(matching(filter, from: center).isEmpty)

        filter.maxDistanceMeters = 2_500
        let near = matching(filter, from: center)
        #expect(!near.isEmpty && near.count < events.count)
        #expect(near.allSatisfy { $0.location.coordinate.distance(to: center) <= 2_500 })
    }

    /// The floor counts who is already in, host included: at it passes, under it is out, and no floor is no criterion.
    @Test func minAttendeesIsAFloorOnWhoIsAlreadyIn() {
        let quiet = SportEvent.fixture(id: "quiet", participants: 2)
        let busy = SportEvent.fixture(id: "busy", participants: 10)
        var filter = EventFilter()
        #expect(matches(filter, quiet) && matches(filter, busy))

        filter.minAttendees = 10
        #expect(!matches(filter, quiet) && matches(filter, busy))
        #expect(filter.isActive)

        filter.minAttendees = 2
        #expect(matches(filter, quiet) && matches(filter, busy))
    }

    /// Morning ends at noon, the afternoon at six; the buckets follow the user's calendar, and a selection is
    /// multi-select like the types.
    @Test func timesOfDayBucketTheStartHour() {
        let dawn = SportEvent.fixture(id: "dawn", startsAt: start(hour: 7))
        let noonish = SportEvent.fixture(id: "noon", startsAt: start(hour: 12))
        let late = SportEvent.fixture(id: "late", startsAt: start(hour: 20))
        var filter = EventFilter()
        #expect(matches(filter, dawn) && matches(filter, late), "no selection is no criterion")

        filter.toggle(TimeOfDay.morning)
        #expect(matches(filter, dawn) && !matches(filter, noonish) && !matches(filter, late))

        filter.toggle(TimeOfDay.afternoon)
        #expect(matches(filter, noonish) && !matches(filter, late))

        filter.toggle(TimeOfDay.morning)
        filter.toggle(TimeOfDay.evening)
        #expect(!matches(filter, dawn) && matches(filter, noonish) && matches(filter, late))
    }

    @Test func theBucketBoundariesAreTheConfiguredHours() {
        #expect(TimeOfDay.of(start(hour: AppConfig.Events.afternoonStartHour - 1)) == .morning)
        #expect(TimeOfDay.of(start(hour: AppConfig.Events.afternoonStartHour)) == .afternoon)
        #expect(TimeOfDay.of(start(hour: AppConfig.Events.eveningStartHour - 1)) == .afternoon)
        #expect(TimeOfDay.of(start(hour: AppConfig.Events.eveningStartHour)) == .evening)
        #expect(TimeOfDay.of(start(hour: 23)) == .evening)
        #expect(TimeOfDay.of(start(hour: 0)) == .morning)
    }

    @Test func levelAndOpenSpotsCriteria() {
        var filter = EventFilter()
        filter.skillLevel = .advanced
        #expect(matching(filter).allSatisfy { $0.skillLevel == .advanced || $0.skillLevel == nil })
        #expect(matching(filter).contains { $0.skillLevel == nil }, "games open to any level stay visible")
        #expect(matching(filter).contains { $0.skillLevel == .advanced })
        #expect(!matching(filter).contains { $0.skillLevel == .beginner || $0.skillLevel == .intermediate })

        filter = EventFilter()
        filter.openSpotsOnly = true
        #expect(matching(filter).allSatisfy { !$0.isFull })
        #expect(matching(filter).count == events.count - events.filter(\.isFull).count)
        #expect(matching(filter).contains { $0.playerLimit == .minimum && $0.hasPlayersNeeded },
                "a game that allows extras has open spots past the number it needs")
        #expect(matching(filter).contains { $0.playerLimit == .unlimited }, "a game without a limit always has spots")
    }

    /// A level this build does not know is treated like no level: the game welcomes anyone as far as the filter can
    /// tell, so it passes every choice, while a known level still has to match the chosen one.
    @Test func anUnknownLevelMatchesEveryChoiceLikeNoLevel() {
        var filter = EventFilter()
        filter.skillLevel = .advanced
        #expect(matches(filter, .fixture(skillLevel: .unknown("pro"))))
        #expect(matches(filter, .fixture(skillLevel: nil)))
        #expect(matches(filter, .fixture(skillLevel: .advanced)))
        #expect(!matches(filter, .fixture(skillLevel: .beginner)))

        filter.skillLevel = nil
        #expect(matches(filter, .fixture(skillLevel: .beginner)), "no choice is no criterion")
    }

    @Test func dateWindowKeepsOnlyGamesStartingInsideIt() {
        let now = Date()
        let firstDay = events.first!.startsAt
        var filter = EventFilter()
        filter.dateWindow = .days(from: firstDay, to: firstDay)
        let sameDay = matching(filter)
        #expect(!sameDay.isEmpty)
        #expect(sameDay.allSatisfy { Calendar.current.isDate($0.startsAt, inSameDayAs: firstDay) })

        filter.dateWindow = .days(from: now.addingTimeInterval(-2 * 86_400), to: now.addingTimeInterval(-86_400))
        #expect(matching(filter).isEmpty, "all fixtures start in the future")
    }

    @Test func criteriaCombineWithAnd() {
        var filter = EventFilter()
        filter.toggle(.football)
        filter.minAttendees = 10
        #expect(matching(filter).isEmpty, "the football fixture has six people in")
        filter.minAttendees = 5
        #expect(matching(filter).map(\.type) == [.football])
    }

    @Test func everythingLiftsTheDefaultRadius() {
        let far = Coordinate(latitude: center.latitude + 0.5, longitude: center.longitude)
        #expect(EventFilter.everything.isActive, "it differs from the default on purpose")
        #expect(matching(EventFilter(), from: far).isEmpty, "the default radius hides games 50 km away")
        #expect(matching(.everything, from: far) == events)
    }

    @Test func clearResetsEveryCriterion() {
        var filter = EventFilter()
        filter.toggle(.running)
        filter.maxDistanceMeters = nil
        filter.minAttendees = 5
        filter.toggle(TimeOfDay.evening)
        filter.skillLevel = .beginner
        filter.dateWindow = .proposal()
        filter.openSpotsOnly = true
        filter.clear()
        #expect(filter == EventFilter())
        #expect(!filter.isActive)
    }
}

struct DateWindowTests {
    private let calendar = Calendar.current

    @Test func daysCoverWholeDaysInclusive() {
        let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 12))!
        let window = DateWindow.days(from: noon, to: noon.addingTimeInterval(86_400), calendar: calendar)
        #expect(window.contains(calendar.startOfDay(for: noon)))
        #expect(window.contains(noon.addingTimeInterval(86_400 + 11 * 3_600)), "23:00 on the last day is inside")
        #expect(!window.contains(noon.addingTimeInterval(2 * 86_400 + 60)))
        #expect(!window.contains(noon.addingTimeInterval(-13 * 3_600)))
    }

    @Test func lastDayBeforeFirstCollapsesToOneDay() {
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 9))!
        let window = DateWindow.days(from: day, to: day.addingTimeInterval(-3 * 86_400), calendar: calendar)
        #expect(window.start == calendar.startOfDay(for: day))
        #expect(window.contains(day) && !window.contains(day.addingTimeInterval(86_400)))
    }

    @Test func proposalSpansTheConfiguredDays() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 15))!
        let window = DateWindow.proposal(from: today, calendar: calendar)
        let span = AppConfig.Events.defaultFilterDateSpanDays
        let lastStart = calendar.date(byAdding: .day, value: span, to: calendar.startOfDay(for: today))!
        #expect(window.start == calendar.startOfDay(for: today))
        #expect(window.contains(lastStart.addingTimeInterval(3_600)))
        #expect(!window.contains(lastStart.addingTimeInterval(86_400)))
    }
}
