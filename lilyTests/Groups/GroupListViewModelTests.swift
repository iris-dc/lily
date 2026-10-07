import Foundation
import Testing
@testable import lily

@MainActor
struct GroupListViewModelTests {
    private let harness = GroupHarness()
    private let sleep = HeldSleep()

    private func makeViewModel(scope: GroupListScope) -> GroupListViewModel {
        GroupListViewModel(scope: scope,
                           store: harness.store,
                           repository: harness.repository,
                           identity: harness.identity,
                           locationService: harness.location,
                           errorCenter: harness.errorCenter,
                           recorder: harness.recorder,
                           logger: harness.logger) { [sleep] in try await sleep.sleep(for: $0) }
    }

    private var mine: [SportGroup] {
        [.fixture(id: "a", role: .member), .fixture(id: "b", role: .admin)]
    }

    /// Mine shows whatever the store holds, so a join made anywhere is on the list without a reload here.
    @Test func mineProjectsTheStore() async {
        harness.repository.result = .success(mine)
        let viewModel = makeViewModel(scope: .mine)
        #expect(viewModel.groups.isEmpty)

        await viewModel.loadIfStale()
        #expect(viewModel.groups == harness.store.groups && viewModel.groups.count == 2)
        #expect(harness.repository.requestedScopes == [.mine])

        harness.store.remove(id: "a")
        #expect(viewModel.groups.map(\.id) == ["b"])

        await viewModel.refresh()
        #expect(harness.repository.requestedScopes == [.mine, .mine])
    }

    /// Home's rows are communities: a conversation in Mine (a Message tap put it there) is the Chats tab's alone.
    @Test func mineLeavesTheConversationsOut() async {
        harness.repository.result = .success(mine + [.conversationFixture(id: "dm")])
        let viewModel = makeViewModel(scope: .mine)

        await viewModel.loadIfStale()

        #expect(viewModel.groups.map(\.id) == ["a", "b"] && harness.store.groups.count == 3)
        #expect(!viewModel.isInitialLoad)
    }

    /// "Joined" on a Discover card is the server's answer for one caller, so another caller earns a new search.
    @Test func discoverSearchesAgainForAnotherCaller() async {
        harness.repository.result = .success([.fixture(id: "p")])
        let viewModel = makeViewModel(scope: .discover)

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)

        harness.identity.currentUserID = "someone-else"
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
    }

    /// The failed state is Mine's (pull to refresh); a failed Discover search already showed the popup.
    @Test func loadFailedFollowsTheStoreForMineOnly() async {
        harness.repository.result = .failure(.groupsUnavailable)
        let mine = makeViewModel(scope: .mine)
        let discover = makeViewModel(scope: .discover)

        await mine.loadIfStale()
        await discover.loadIfStale()

        #expect(mine.loadFailed && !discover.loadFailed)
    }

    @Test func mineIgnoresTheSearchFields() async {
        let viewModel = makeViewModel(scope: .mine)

        viewModel.query = "kick"
        viewModel.typeFilter = .football
        for _ in 0..<10 { await Task.yield() }

        #expect(sleep.requested.isEmpty && harness.repository.requestedScopes.isEmpty)
    }

    /// Discover is for guests too: nothing here asks who the caller is.
    @Test func discoverLoadsOnceAndAgainOnRefreshForGuests() async {
        harness.identity.currentUserID = nil
        harness.repository.result = .success([.fixture(id: "p")])
        let viewModel = makeViewModel(scope: .discover)

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes == [.discover(query: nil, type: nil)])
        #expect(viewModel.groups.map(\.id) == ["p"] && viewModel.hasSearched && !viewModel.isDiscoverEmpty)

        await viewModel.refresh()
        #expect(harness.repository.requestedScopes.count == 2)
    }

    @Test func typingWaitsForTheDebounceAndSendsTheLastQuery() async {
        harness.repository.result = .success([])
        let viewModel = makeViewModel(scope: .discover)

        viewModel.query = "ber"
        await settle(until: { sleep.requested.count == 1 })
        #expect(sleep.requested == [AppConfig.Groups.searchDebounce])
        #expect(harness.repository.requestedScopes.isEmpty)

        viewModel.query = "berl"
        await settle(until: { sleep.requested.count == 2 })
        sleep.release()
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        #expect(harness.repository.requestedScopes == [.discover(query: "berl", type: nil)])
        #expect(viewModel.isDiscoverEmpty)
    }

    /// The cap counts UTF-16 units like Laurel's `@Size`: letters up to the limit plus an emoji would be one character
    /// over on the wire and earn a 400 on every keystroke, so the emoji is dropped.
    @Test func theQueryIsTrimmedCappedAndAbsentWhenBlank() {
        let viewModel = makeViewModel(scope: .discover)
        #expect(viewModel.effectiveQuery == nil)

        viewModel.query = "   "
        #expect(viewModel.effectiveQuery == nil)

        viewModel.query = " " + String(repeating: "k", count: AppConfig.Groups.queryMaxLength + 5) + " "
        #expect(viewModel.effectiveQuery?.wireLength == AppConfig.Groups.queryMaxLength)

        let letters = String(repeating: "k", count: AppConfig.Groups.queryMaxLength - 1)
        viewModel.query = letters + "😀"
        #expect(viewModel.effectiveQuery == letters)
        #expect(viewModel.effectiveQuery.wireLength <= AppConfig.Groups.queryMaxLength)
        viewModel.cancel()
    }

    @Test func changingTheTypeSearchesAtOnce() async {
        harness.repository.result = .success([.fixture(id: "f", type: .football)])
        let viewModel = makeViewModel(scope: .discover)

        viewModel.typeFilter = .football
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        #expect(sleep.requested.isEmpty)
        #expect(harness.repository.requestedScopes == [.discover(query: nil, type: .football)])
        #expect(viewModel.groups.map(\.id) == ["f"])
    }

    /// Statistics carry whether a name was typed and how many came back; the name itself stays on the device.
    @Test func searchRecordsWhetherSomethingWasTypedAndTheCount() async {
        harness.repository.result = .success([.fixture(id: "a"), .fixture(id: "b")])
        let viewModel = makeViewModel(scope: .discover)

        await viewModel.search()
        viewModel.query = "Kreuzberg Kickers"
        await settle(until: { sleep.requested.count == 1 })
        sleep.release()
        await settle(until: { harness.repository.requestedScopes.count == 2 })

        let recorded = harness.recorder.interactions
        #expect(recorded.map(\.kind) == [.groupSearchPerformed, .groupSearchPerformed])
        #expect(recorded.map(\.hasQuery) == [false, true])
        #expect(recorded.map(\.resultCount) == [2, 2])
        #expect(recorded.allSatisfy { $0.groupId == nil })
        #expect(!harness.logs().joined().contains("Kreuzberg"))
    }

    @Test func pagesFollowTheCursorWithoutRepeatingAGroup() async {
        harness.repository.result = .success([.fixture(id: "a"), .fixture(id: "b")])
        harness.repository.nextCursor = "c1"
        let viewModel = makeViewModel(scope: .discover)
        await viewModel.search()
        #expect(viewModel.canLoadMore)

        harness.repository.result = .success([.fixture(id: "b"), .fixture(id: "c")])
        harness.repository.nextCursor = nil
        await viewModel.loadMore()

        #expect(viewModel.groups.map(\.id) == ["a", "b", "c"])
        #expect(!viewModel.canLoadMore)
        #expect(harness.repository.requestedCursors == [nil, "c1"])

        await viewModel.loadMore()
        #expect(harness.repository.requestedCursors.count == 2, "no cursor, no request")
    }

    /// A page that answers after a new search began belongs to the old query and is dropped.
    @Test func aNewSearchDropsThePageOfTheOldOne() async {
        harness.repository.result = .success([.fixture(id: "old")])
        harness.repository.nextCursor = "c1"
        let viewModel = makeViewModel(scope: .discover)
        await viewModel.search()

        harness.repository.holdsRequests = true
        let paging = Task { await viewModel.loadMore() }
        await settle(until: { harness.repository.requestedCursors.count == 2 })
        harness.repository.holdsRequests = false
        harness.repository.result = .success([.fixture(id: "new")])
        harness.repository.nextCursor = nil
        await viewModel.search()
        harness.repository.releaseRequests()
        await paging.value

        #expect(viewModel.groups.map(\.id) == ["new"])
        #expect(!viewModel.isLoadingMore)
    }

    @Test func aFailedSearchReachesThePopup() async {
        harness.repository.result = .failure(.groupsUnavailable)
        let viewModel = makeViewModel(scope: .discover)

        await viewModel.search()

        #expect(harness.presentedError == .groupsUnavailable)
        #expect(harness.logs(.error).count == 1)
        #expect(!viewModel.isLoading)
    }

    @Test func cancelStopsAPendingSearch() async {
        let viewModel = makeViewModel(scope: .discover)
        viewModel.query = "x"
        await settle(until: { sleep.requested.count == 1 })

        viewModel.cancel()
        for _ in 0..<10 { await Task.yield() }

        #expect(harness.repository.requestedScopes.isEmpty)
        #expect(viewModel.searchTask == nil)
    }
}
