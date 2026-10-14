import Foundation
import Testing
@testable import lily

/// Explore's filter between launches: what is kept, what is not, and what a stored value that no longer reads does.
@MainActor
struct EventFilterStoreTests {
    private let defaults = makeTestDefaults()
    private let logger = SpyLogger()

    private var store: UserDefaultsEventFilterStore { UserDefaultsEventFilterStore(defaults: defaults, logger: logger) }

    private static func makeFilter() -> EventFilter {
        var filter = EventFilter()
        filter.toggle(.tennis)
        filter.toggle(.football)
        filter.maxDistanceMeters = 25_000
        filter.maxPrice = 12.5
        filter.skillLevel = .intermediate
        filter.openSpotsOnly = true
        return filter
    }

    @Test func nothingStoredReadsAsNoneAndLogsTheMiss() {
        #expect(store.load() == nil)
        #expect(logger.count(in: .cache, at: .debug) == 1)
        #expect(logger.hasLine(in: .cache, at: .debug, mentioning: "defaults"))
    }

    /// Every criterion but the date window comes back; the window would be stale within days. The save and the hit
    /// are logged with whether the filter narrows anything, never with its criteria.
    @Test func aSavedFilterComesBackWithoutItsDateWindow() throws {
        var filter = Self.makeFilter()
        filter.dateWindow = DateWindow(start: .now, end: .now.addingTimeInterval(86_400))

        store.save(filter)

        var expected = filter
        expected.dateWindow = nil
        #expect(store.load() == expected)
        #expect(UserDefaultsEventFilterStore(defaults: defaults, logger: logger).load() == expected, "it is in the defaults")
        #expect(logger.hasLine(in: .cache, at: .debug, mentioning: "stored", "active: true"))
        #expect(logger.count(in: .cache, at: .info) == 2, "both loads are logged")
        #expect(logger.count(in: .cache, at: .info, mentioning: "restored", "active: true") == 2)
        #expect(!logger.messages(in: .cache).contains { $0.contains("tennis") || $0.contains("25") })
    }

    /// "Anywhere" is a choice away from the default radius and must survive as one: `nil` stored is `nil` back.
    @Test func anywhereAndTheDefaultsRoundTrip() {
        store.save(.everything)
        #expect(store.load() == .everything)

        store.save(EventFilter())
        #expect(store.load() == EventFilter())
    }

    @Test func clearForgetsTheFilter() {
        store.save(Self.makeFilter())
        store.clear()
        #expect(store.load() == nil && defaults.data(forKey: AppConfig.Storage.Keys.eventFilter) == nil)
        #expect(logger.count(in: .cache, at: .info) == 1)
        #expect(logger.hasLine(in: .cache, at: .info, mentioning: "cleared"))
    }

    /// A filter kept by a newer build may name a type or a level this one does not know; the panel could neither show
    /// nor clear such a criterion, so it is left out and the rest of the filter comes back, without a warning.
    @Test func aStoredTypeOrLevelThisBuildDoesNotKnowIsLeftOut() throws {
        let stored = #"{"types":["quidditch","tennis"],"skillLevel":"pro","openSpotsOnly":true}"#
        defaults.set(Data(stored.utf8), forKey: AppConfig.Storage.Keys.eventFilter)

        let filter = try #require(store.load())
        #expect(filter.types == [.tennis])
        #expect(filter.skillLevel == nil && filter.openSpotsOnly)
        #expect(logger.messages(in: .cache, at: .warning).isEmpty)
    }

    /// A value a later build cannot read (a hand-edited plist, a stray shape) is a warning and the defaults, never a crash.
    @Test func anUnreadableValueReadsAsNoneWithAWarning() {
        defaults.set(Data("not json".utf8), forKey: AppConfig.Storage.Keys.eventFilter)

        #expect(store.load() == nil)
        #expect(logger.messages(in: .cache, at: .warning).count == 1)
    }

    /// The stored shape: sorted types, the key names the backend-independent model uses, no `null`s.
    @Test func thePersistedShapeSortsTypesAndOmitsAbsentCriteria() throws {
        let persisted = PersistedEventFilter(Self.makeFilter())
        #expect(persisted.types == [.football, .tennis])
        #expect(persisted.filter == Self.makeFilter())

        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(PersistedEventFilter(.everything)))
                                as? [String: Any])
        #expect(Set(json.keys) == ["types", "openSpotsOnly"])
    }
}
