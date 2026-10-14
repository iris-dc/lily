import Testing
@testable import lily

struct TournamentModelTests {
    @Test func isNearlyFullFollowsTheFillRatio() {
        let nearlyFull = Tournament.fixture(maxEntries: 8, entryCount: 6)
        #expect(nearlyFull.isNearlyFull)
        #expect(!nearlyFull.isFull)

        let full = Tournament.fixture(maxEntries: 8, entryCount: 8)
        #expect(full.isFull)
        #expect(!full.isNearlyFull)

        let open = Tournament.fixture(maxEntries: 8, entryCount: 2)
        #expect(!open.isFull)
        #expect(!open.isNearlyFull)

        let noField = Tournament.fixture(maxEntries: 0, entryCount: 0)
        #expect(noField.isFull)
        #expect(!noField.isNearlyFull)
    }
}
