import Foundation
import Testing
@testable import lily

/// The Mine order contract on the store, in a sibling file because the main suite's body is near the limit.
extension MyGroupsStoreTests {
    /// Laurel's `listMine_readsAndSorts` literal: the busy group first, then the silent ones by creation.
    @Test func mineOrdersByLastActivityThenCreation() async {
        repository.result = .success([])
        let store = makeStore()
        await store.reload()
        let busy = SportGroup.fixture(id: "busy",
                                      name: "Zebra",
                                      lastMessageAt: Self.start + 60,
                                      createdAt: Self.start - 1000,
                                      role: .admin)
        let silentNewer = SportGroup.fixture(id: "silent-newer", name: "Yak", createdAt: Self.start - 10, role: .member)
        let silentOlder = SportGroup.fixture(id: "silent-older", name: "Aardvark", createdAt: Self.start - 500, role: .member)

        store.add(silentOlder)
        store.add(busy)
        store.add(silentNewer)

        #expect(store.groups.map(\.id) == ["busy", "silent-newer", "silent-older"],
                "the newest message first, silent groups by creation, never by name")
        #expect(store.groups.map(\.id) == store.groups.sorted(by: SportGroup.mineOrder).map(\.id))
    }

    /// Equal activity (a message at `start`, a creation at `start`) is placed by name, as a reload would place it.
    @Test func aTieInActivityIsPlacedByNameAsAReloadWouldPlaceIt() async {
        repository.result = .success([.fixture(id: "a", name: "Alt", lastMessageAt: Self.start, role: .member),
                                      .fixture(id: "p", name: "Pankow", createdAt: Self.start, role: .member)])
        let store = makeStore()
        await store.reload()

        store.add(.fixture(id: "k", name: "Kreuzberg", createdAt: Self.start, role: .member))
        store.add(.fixture(id: "z", name: "Zehlendorf", lastMessageAt: Self.start, role: .member))

        #expect(store.groups.map(\.id) == ["a", "k", "p", "z"])
    }
}
