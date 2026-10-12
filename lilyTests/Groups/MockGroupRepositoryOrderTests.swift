import Foundation
import Testing
@testable import lily

/// Mine's order against the backend's contract, in a sibling file because the main suite's body is near the limit.
extension MockGroupRepositoryTests {
    /// A group created now is silent and the newest activity, so it leads Mine (under a `nullsLast` order it came last);
    /// every row with a message precedes the silent Kickers Cup room, whose creation is older than their messages.
    @Test func theMockOrdersMineLikeTheBackend() async throws {
        let repository = makeRepository()
        let created = try await repository.create(.fixture())

        let mine = try await repository.groups(in: .mine, cursor: nil, near: nil).items

        #expect(mine.first?.id == created.id, "a group just created leads Mine, as it will after the reload")
        #expect(mine.map(\.id) == mine.sorted(by: SportGroup.mineOrder).map(\.id))
        let silent = mine.filter { $0.lastMessageAt == nil }
        #expect(silent.map(\.name) == [created.name, "Kickers Cup"])
        let lastWithMessage = try #require(mine.firstIndex { $0.name == "Sunday Padel Crew" })
        let silentFixture = try #require(mine.firstIndex { $0.name == "Kickers Cup" })
        #expect(lastWithMessage < silentFixture, "the silent fixture follows every row with a message")
    }
}
