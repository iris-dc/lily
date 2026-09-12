import Foundation
import Testing
@testable import lily

struct EventFilterTests {
    private let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize)
    private let center = AppConfig.Location.mockCenter

    private func matching(_ filter: EventFilter, from origin: Coordinate? = nil) -> [SportEvent] {
        events.filter { filter.matches($0, from: origin) }
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
        #expect(matching(filter).map(\.type).sorted { $0.rawValue < $1.rawValue } == [.padel, .tennis])
    }

    @Test func otherIsAFilterableType() {
        var filter = EventFilter()
        filter.toggle(.other)
        #expect(matching(filter).map(\.title) == ["Sunrise yoga"])
        #expect(EventType.other.displayName == "Other")
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

    @Test func maxPriceTreatsMissingPriceAsFreeAndZeroAsFreeOnly() {
        let free = SportEvent.fixture()
        let cheap = SportEvent.fixture(price: Price(amount: 5, currencyCode: "EUR"))
        let dear = SportEvent.fixture(price: Price(amount: 12, currencyCode: "EUR"))
        var filter = EventFilter()
        #expect(filter.matches(dear, from: nil))

        filter.maxPrice = 0
        #expect(filter.matches(free, from: nil) && !filter.matches(cheap, from: nil))

        filter.maxPrice = 5
        #expect(filter.matches(free, from: nil) && filter.matches(cheap, from: nil) && !filter.matches(dear, from: nil))
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
        filter.maxPrice = 0
        #expect(matching(filter).isEmpty, "the only football fixture costs money")
        filter.maxPrice = 5
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
        filter.maxPrice = 0
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
