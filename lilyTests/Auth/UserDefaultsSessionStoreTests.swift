import Foundation
import Testing
@testable import lily

@MainActor
struct UserDefaultsSessionStoreTests {
    private func makeStore() -> UserDefaultsSessionStore {
        let suite = "lily.tests.\(UUID().uuidString)"
        return UserDefaultsSessionStore(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func roundTripsSignedInSession() {
        let store = makeStore()
        store.save(.signedIn(TestFixtures.session))
        #expect(store.load() == .signedIn(TestFixtures.session))
    }

    @Test func roundTripsGuest() {
        let store = makeStore()
        store.save(.guest)
        #expect(store.load() == .guest)
    }

    @Test func clearRemovesValue() {
        let store = makeStore()
        store.save(.guest)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func emptyStoreReturnsNil() {
        #expect(makeStore().load() == nil)
    }
}
