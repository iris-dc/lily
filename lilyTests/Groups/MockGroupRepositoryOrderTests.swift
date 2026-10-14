import Foundation
import Testing
@testable import lily

/// Mine's and Discover's orders against the backend's contract, in a sibling file because the main suite's body is near
/// the limit.
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

    /// The backend reads a blank query as none and trims the rest, so the mock browses on a blank one (nearest first
    /// around the position, as without a query) and the remote sends no `q` but the position, and the trimmed prefix
    /// without the position for a typed one.
    @Test func aBlankQueryIsABrowseOnBothSides() async throws {
        let center = AppConfig.Location.mockCenter
        let repository = makeRepository()
        let browse = try await repository.groups(in: .discover(query: nil, type: nil), cursor: nil, near: center).items
        #expect(browse.map(\.name) == ["Spree Volley", "Berlin Basketball", "Kreuzberg Kickers", "Tempelhof Runners"])
        for blank in ["", "   "] {
            let page = try await repository.groups(in: .discover(query: blank, type: nil), cursor: nil, near: center)
            #expect(page.items.map(\.id) == browse.map(\.id), "a blank query is a browse")
        }
        let searched = try await repository.groups(in: .discover(query: "ber", type: nil), cursor: nil, near: center)
        #expect(searched.items.map(\.name) == ["Berlin Basketball"])

        let client = FakeAPIClient()
        client.responses = [Page<SportGroup>(items: []), Page<SportGroup>(items: [])]
        let remote = RemoteGroupRepository(client: client, identity: identity)
        _ = try await remote.groups(in: .discover(query: "  ", type: nil), cursor: nil, near: center)
        _ = try await remote.groups(in: .discover(query: " ber ", type: nil), cursor: nil, near: center)
        #expect(client.requests[0].queryItems.map(\.name) == ["scope", "limit", "lat", "lon"])
        #expect(client.requests[1].queryItems.map(\.name) == ["scope", "q", "limit"])
        #expect(client.requests[1].queryItems.first { $0.name == "q" }?.value == "ber")
    }
}
