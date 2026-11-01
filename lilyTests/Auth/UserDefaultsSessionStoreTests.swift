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
            defaults = makeTestDefaults()
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

    @Test func roundTripsThePendingSignOutMarker() {
        let store = makeStore()
        store.save(.signingOut)
        #expect(store.load() == .signingOut)
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

    /// A session cached before the name moved to the backend profile carries a `displayName` key the decoder ignores,
    /// so an upgrading user stays signed in.
    @Test func aLegacyBlobWithADisplayNameStillLoadsTheSignedInSession() {
        let harness = Harness()
        let legacy = #"{"signedIn":{"_0":{"user":{"id":"u-1","email":"test@example.com","displayName":"Jane"}}}}"#
        harness.defaults.set(Data(legacy.utf8), forKey: AppConfig.Storage.Keys.storedSession)

        #expect(harness.store.load() == .signedIn(TestFixtures.session))
        #expect(harness.logger.entries.allSatisfy { $0.level != .warning })
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
