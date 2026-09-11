import Foundation
import Testing
@testable import lily

@MainActor
struct UserDefaultsSessionStoreTests {
    @MainActor private struct Harness {
        let defaults: UserDefaults
        let logger = SpyLogger()
        let store: UserDefaultsSessionStore

        init() {
            defaults = UserDefaults(suiteName: "lily.tests.\(UUID().uuidString)")!
            store = UserDefaultsSessionStore(defaults: defaults, logger: logger)
        }
    }

    private func makeStore() -> UserDefaultsSessionStore { Harness().store }

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

    @Test func corruptBlobLoadsAsNilAndIsRemoved() {
        let harness = Harness()
        harness.defaults.set(Data("junk".utf8), forKey: AppConfig.Storage.Keys.storedSession)

        #expect(harness.store.load() == nil)

        #expect(harness.defaults.data(forKey: AppConfig.Storage.Keys.storedSession) == nil)
        let warnings = harness.logger.entries.filter { $0.level == .warning && $0.category == .cache }
        #expect(warnings.count == 1)
    }

    @Test func logsCacheHitMissAndInvalidation() {
        let harness = Harness()

        _ = harness.store.load()
        harness.store.save(.guest)
        _ = harness.store.load()
        harness.store.clear()

        let messages = harness.logger.messages(in: .cache)
        #expect(messages.contains { $0.contains("miss") })
        #expect(messages.contains { $0.contains("hit") })
        #expect(messages.contains { $0.contains("invalidated") })
    }
}
