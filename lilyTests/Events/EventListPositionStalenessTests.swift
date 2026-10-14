import Foundation
import Testing
@testable import lily

/// When the user's position makes Explore content stale: the backend orders by distance, so content loaded without a
/// position that is known now, or for another one than the user's, is asked for again, once; Home never is.
@MainActor
struct EventListPositionStalenessTests {
    /// Explore loaded once for `mockCenter`, the service answering it, so the position is known and the content is
    /// current for it.
    private func makeExploreLoaded(repository: FakeEventRepository,
                                   service: FakeLocationService,
                                   errorCenter: ErrorCenter? = nil,
                                   logger: SpyLogger? = nil) async -> EventListViewModel {
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: repository,
                                               locationService: service,
                                               errorCenter: errorCenter,
                                               logger: logger)
        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()
        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter])
        return viewModel
    }

    /// Explore loaded before the position was known is in plain time order; once known, one reload lets the backend
    /// order by distance. One: the second load carries the position, so the content is not stale for it again.
    @Test func exploreReloadsOnceWhenThePositionBecomesKnown() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let logger = SpyLogger()
        let viewModel = makeEventListViewModel(repository: repository, locationService: service, logger: logger)
        await viewModel.loadIfStale()
        #expect(repository.requestedPositions == [nil])

        service.result = AppConfig.Location.mockCenter
        await viewModel.loadUserLocation()
        #expect(repository.requestedPositions == [nil, AppConfig.Location.mockCenter])
        #expect(logger.messages(in: .cache).contains { $0.contains("position became known") })

        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    @Test func noReloadWhenTheFirstLoadAlreadyHadThePosition() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let viewModel = await makeExploreLoaded(repository: repository, service: service)

        await viewModel.loadIfStale()

        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter])
    }

    /// The position arrived while the first request was out, so that answer is in time order: asked again at once.
    @Test func aPositionArrivingMidLoadEarnsOneReload() async {
        let repository = FakeEventRepository()
        repository.holdsRequests = true
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: repository, locationService: service)

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { viewModel.isLoading })
        await viewModel.loadUserLocation()
        #expect(repository.requestedScopes.count == 1, "nothing extra while the request is out")
        repository.releaseRequests()
        await load.value

        #expect(repository.requestedPositions == [nil, AppConfig.Location.mockCenter])
        #expect(!viewModel.isLoading)
    }

    /// Explore was loaded for where the user was; after a day elsewhere the backend's order, the distances and the
    /// radius are for the old place, so the content is stale for the new position and reloads once.
    @Test func exploreReloadsOnceWhenTheUserMoved() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let logger = SpyLogger()
        let viewModel = await makeExploreLoaded(repository: repository, service: service, logger: logger)

        service.result = TestFixtures.elsewhere
        await viewModel.refreshUserLocation()
        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter, TestFixtures.elsewhere])
        #expect(logger.messages(in: .cache).contains { $0.contains("position changed") })

        await viewModel.loadIfStale()
        #expect(repository.requestedScopes.count == 2)
    }

    /// Positions are compared as the backend receives them (`positionPrecision`, about a kilometre), so GPS drift
    /// between two fixes never reloads.
    @Test func aMoveWithinTheRoundingIsNotAMove() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let viewModel = await makeExploreLoaded(repository: repository, service: service)

        service.result = Coordinate(latitude: AppConfig.Location.mockCenter.latitude + 0.001,
                                    longitude: AppConfig.Location.mockCenter.longitude)
        await viewModel.refreshUserLocation()
        await viewModel.loadIfStale()

        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter])
    }

    /// The user moved while the request was out, so that answer is for the old place: asked again at once.
    @Test func aMoveMidLoadEarnsOneReload() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        service.result = AppConfig.Location.mockCenter
        let viewModel = makeEventListViewModel(repository: repository, locationService: service)
        await viewModel.loadUserLocation()
        repository.holdsRequests = true

        let load = Task { await viewModel.loadIfStale() }
        await settle(until: { viewModel.isLoading })
        service.result = TestFixtures.elsewhere
        await viewModel.loadUserLocation()
        #expect(repository.requestedScopes.count == 1, "nothing extra while the request is out")
        repository.releaseRequests()
        await load.value

        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter, TestFixtures.elsewhere])
        #expect(!viewModel.isLoading)
    }

    /// Home is the caller's own games in start order; a position changes nothing there.
    @Test func joinedNeverReloadsForAPosition() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let viewModel = makeEventListViewModel(scope: .joined, repository: repository, locationService: service)
        await viewModel.loadIfStale()

        service.result = AppConfig.Location.mockCenter
        await viewModel.loadUserLocation()
        await viewModel.loadIfStale()

        #expect(repository.requestedPositions == [nil])
    }

    /// A move while a refresh is out that then fails earns no reload: the answer that never came is for no place, the
    /// popup shows once, and the cooldown is judged on the version and the caller, which a position does not end.
    @Test func aFailedLoadAfterASuccessNeverEarnsThePositionReload() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let errorCenter = ErrorCenter(logger: SpyLogger())
        let viewModel = await makeExploreLoaded(repository: repository, service: service, errorCenter: errorCenter)
        repository.holdsRequests = true
        repository.result = .failure(.network)

        let load = Task { await viewModel.load() }
        await settle(until: { viewModel.isLoading })
        service.result = TestFixtures.elsewhere
        await viewModel.loadUserLocation()
        #expect(repository.requestedScopes.count == 2, "nothing extra while the request is out")
        repository.releaseRequests()
        await load.value
        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter, AppConfig.Location.mockCenter])
        #expect(viewModel.loadFailed)
        #expect(errorCenter.current?.error == .network)

        await viewModel.loadIfStale()
        #expect(repository.requestedPositions.count == 2)
    }

    /// A move while a refresh is out that is then cancelled (the screen left) earns no reload either, and no popup; the
    /// next appearance asks for the new place once.
    @Test func aCancelledLoadAfterASuccessNeverEarnsThePositionReload() async {
        let repository = FakeEventRepository()
        let service = FakeLocationService()
        let errorCenter = ErrorCenter(logger: SpyLogger())
        let viewModel = await makeExploreLoaded(repository: repository, service: service, errorCenter: errorCenter)
        repository.holdsRequests = true
        repository.thrownError = CancellationError()

        let load = Task { await viewModel.load() }
        await settle(until: { viewModel.isLoading })
        service.result = TestFixtures.elsewhere
        await viewModel.loadUserLocation()
        repository.releaseRequests()
        await load.value
        #expect(repository.requestedPositions == [AppConfig.Location.mockCenter, AppConfig.Location.mockCenter])
        #expect(!viewModel.loadFailed)
        #expect(errorCenter.current == nil)

        repository.thrownError = nil
        await viewModel.loadIfStale()
        #expect(repository.requestedPositions.count == 3)
        #expect(repository.requestedPositions.last == TestFixtures.elsewhere)
    }
}
