import Foundation
import Testing
@testable import lily

@MainActor
struct MockEventRepositoryTests {
    /// `count` sizes the fixture set; Explore lists all of them but the private group's game (index 3), like the backend.
    @Test func upcomingListsTheRequestedFixturesButThePrivateGroups() async throws {
        let repository = MockEventRepository(now: .now, count: 5, identity: FakeIdentityProvider(), logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        #expect(upcoming.count == 4)
        #expect(upcoming.allSatisfy { $0.isListed })
    }

    @Test func joinedIsNonEmptyStrictSubsetOfUpcoming() async throws {
        let repository = MockEventRepository(now: .now, count: 8, identity: FakeIdentityProvider(), logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        let joined = try await repository.events(in: .joined, near: nil)
        #expect(!joined.isEmpty)
        #expect(joined.count < upcoming.count)
        #expect(joined.allSatisfy(upcoming.contains))
    }

    /// A cap is never exceeded; a game that allows extras may stand past the number it needs.
    @Test func fixturesNeverExceedACap() throws {
        for event in MockEventFixtures.make(now: .now, count: 40) where event.playerLimit == .maximum {
            let capacity = try #require(event.capacity)
            #expect(event.participantCount <= capacity)
            #expect(event.spotsLeft >= 0)
        }
    }

    /// Explore shows a game short of the players it needs, one past them and one without any limit; none can be full.
    @Test func feedSizedFixturesShowEveryKindOfOpenGame() {
        let listed = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
        let needing = listed.filter { $0.playerLimit == .minimum }
        #expect(needing.contains { !$0.hasPlayersNeeded })
        #expect(needing.contains { $0.hasPlayersNeeded && $0.spotsLeft == 0 })
        #expect(listed.contains { $0.playerLimit == .unlimited && $0.participantCount > 0 })
        #expect(listed.filter { $0.playerLimit != .maximum }.allSatisfy { !$0.isFull })
    }

    @Test func fixturesAreInTheFutureAndChronological() {
        let now = Date()
        let events = MockEventFixtures.make(now: now, count: 5)
        #expect(events.allSatisfy { $0.startsAt > now })
        #expect(events.map(\.startsAt) == events.map(\.startsAt).sorted())
    }

    /// Two fixtures are hosted in groups (one public, one private), so the badge and "Hosted in" have data. Like the
    /// backend, Explore lists the public group's game only; the private group's is found under its group's scope.
    @Test func groupedFixturesFollowTheirGroupsVisibility() async throws {
        let repository = MockEventRepository(now: .now,
                                             count: AppConfig.Events.mockFeedSize,
                                             identity: FakeIdentityProvider(),
                                             logger: SpyLogger())
        let upcoming = try await repository.events(in: .upcoming, near: nil)
        let kickers = try await repository.events(in: .group(id: MockGroupFixtures.kickersID), near: nil)
        let padel = try await repository.events(in: .group(id: MockGroupFixtures.padelID), near: nil)

        #expect(upcoming.filter { $0.group != nil } == kickers)
        #expect(kickers.map(\.group?.visibility) == [.public])
        #expect(padel.map(\.group?.visibility) == [.private])
        #expect(!upcoming.contains { $0.group?.isPrivate == true })
        #expect((kickers + padel).allSatisfy { $0.group?.isDeleted == false })
        #expect(try await repository.events(in: .group(id: "nowhere"), near: nil).isEmpty)
    }

    /// The map UI test taps a pin by its title, and templates repeat once the feed outgrows them.
    @Test func feedSizedFixturesHaveUniqueTitles() {
        let titles = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).map(\.title)
        #expect(Set(titles).count == titles.count)
    }

    /// Keeps the map's selected-pin card exercising the "Full" copy, which once read "0 spots left"; the full game must
    /// be one Explore lists, since the private group's game is not.
    @Test func feedSizedFixturesIncludeAFullEvent() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
        #expect(events.contains { $0.isFull })
    }

    /// The feed should show every capacity state of the bar: an open, a nearly full (amber) and a full event.
    @Test func feedSizedFixturesCoverEveryCapacityState() {
        let events = MockEventFixtures.make(now: .now, count: AppConfig.Events.mockFeedSize).filter(\.isListed)
        #expect(events.contains { $0.isNearlyFull })
        #expect(events.contains { !$0.isNearlyFull && !$0.isFull && $0.participantCount > 0 })
    }
}
