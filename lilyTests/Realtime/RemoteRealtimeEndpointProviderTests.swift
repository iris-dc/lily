import Foundation
import Testing
@testable import lily

/// Where a real backend's realtime endpoint comes from: the debug override, else the account, else the production
/// constant; the provider reads the loaded account and never fetches one.
@MainActor
struct RemoteRealtimeEndpointProviderTests {
    private let repository = FakeMeRepository()
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let accountURL = URL(string: "https://abc.appsync-realtime-api.eu-central-1.amazonaws.com/event")!
    private let overrideURL = URL(string: "https://override.test/event")!

    private func makeStore() -> MeStore {
        MeStore(repository: repository, identity: identity, errorCenter: ErrorCenter(logger: logger), logger: logger)
    }

    @Test func theEndpointComesFromTheAccountUnlessOverridden() async {
        repository.meResult = .success(.fixture(realtimeEndpoint: accountURL))
        let me = makeStore()
        await me.loadIfNeeded()

        #expect(await RemoteRealtimeEndpointProvider(override: nil, me: me).endpoint() == accountURL)
        #expect(await RemoteRealtimeEndpointProvider(override: overrideURL, me: me).endpoint() == overrideURL)
        #expect(repository.meCallCount == 1, "the provider reads the store and never fetches")
    }

    @Test func noEndpointBeforeTheAccountLoads() async {
        let provider = RemoteRealtimeEndpointProvider(override: nil, me: makeStore())

        #expect(await provider.endpoint() == nil)
        #expect(repository.meCallCount == 0)
    }

    @Test func anAccountNamingNoEndpointFallsToTheProductionConstant() async {
        repository.meResult = .success(.fixture())
        let me = makeStore()
        await me.loadIfNeeded()

        #expect(await RemoteRealtimeEndpointProvider(override: nil, me: me).endpoint()
                == AppConfig.Realtime.productionEndpoint, "nil until rose's realtime stack is deployed")
    }
}
