import Foundation
import Testing
@testable import lily

/// The mock creates in memory the way the backend does, so `-mock-events` runs and previews can host a game.
@MainActor
struct MockEventRepositoryCreateTests {
    private let repository = MockEventRepository(now: .now,
                                                 count: AppConfig.Events.mockFeedSize,
                                                 identity: FakeIdentityProvider(currentUserID: TestFixtures.user.id),
                                                 logger: SpyLogger())

    @Test func createAnswersAJoinedGameHostedByTheCaller() async throws {
        let draft = EventDraft.fixture(clientId: "3f2504e0-4f89-11d3-9a0c-0305e82c3301")

        let created = try await repository.create(draft)

        #expect(created.id == draft.clientId)
        #expect(created.hostUserId == TestFixtures.user.id)
        #expect(created.hostName == AppBranding.Events.Create.mockHostName)
        #expect(created.participates && created.participantCount == 1)
        #expect(created.title == draft.trimmedTitle && created.locationName == draft.trimmedLocationName)
        #expect(created.location.coordinate == draft.coordinate)
        #expect(created.type == draft.type && created.startsAt == draft.startsAt && created.capacity == draft.capacity)
        #expect(Participation(event: created, userID: TestFixtures.user.id) == .hosting)
    }

    @Test func aCreatedGameIsListedUnderBothScopes() async throws {
        let created = try await repository.create(.fixture())

        #expect(try await repository.events(in: .upcoming, near: nil).contains(created))
        #expect(try await repository.events(in: .joined, near: nil).contains(created))
        #expect(try await repository.event(id: created.id) == created)
    }

    /// Like the backend: the client id is the event id, so a create repeated after a lost answer finds its game.
    @Test func aRepeatedClientIdAnswersTheSameGameOnce() async throws {
        let draft = EventDraft.fixture()

        let first = try await repository.create(draft)
        let second = try await repository.create(draft)

        #expect(second == first)
        let ids = try await repository.events(in: .upcoming, near: nil).map(\.id)
        #expect(ids.contains(draft.clientId))
        #expect(Set(ids).count == ids.count)
        #expect(try await repository.event(id: draft.clientId).participantCount == 1)
    }

    @Test func createCarriesTheOptionalDetails() async throws {
        var draft = EventDraft.fixture()
        draft.description = " Two halves "
        draft.lookingFor = "One keeper"
        draft.skillLevel = .advanced
        draft.price = Decimal(string: "7.5")

        let created = try await repository.create(draft)

        #expect(created.description == "Two halves")
        #expect(created.lookingFor == "One keeper")
        #expect(created.skillLevel == .advanced)
        #expect(created.price == Price(amount: Decimal(string: "7.5")!, currencyCode: EventDraft.testCurrencyCode))
    }

    @Test func aFreeGameHasNoPriceAndBlankDetailsStayAbsent() async throws {
        var draft = EventDraft.fixture()
        draft.price = 0
        draft.description = "   "

        let created = try await repository.create(draft)

        #expect(created.price == nil && created.isFree)
        #expect(created.description == nil && created.lookingFor == nil && created.skillLevel == nil)
    }

    /// A game hosted in a group keeps its badge, and the group's scope lists it.
    @Test func createCarriesTheGroupIntoItsScope() async throws {
        var draft = EventDraft.fixture()
        let kickers = try #require(MockGroupFixtures.ref(for: MockGroupFixtures.kickersID))
        draft.group = kickers

        let created = try await repository.create(draft)

        #expect(created.group == kickers)
        #expect(try await repository.events(in: .group(id: kickers.id), near: nil).contains(created))
        #expect(try await repository.events(in: .group(id: MockGroupFixtures.padelID), near: nil).contains(created) == false)
    }

    @Test func createWithoutACoordinateIsRefused() async {
        await #expect(throws: AppError.eventCreationFailed) { try await repository.create(.fixture(coordinate: nil)) }
    }
}
