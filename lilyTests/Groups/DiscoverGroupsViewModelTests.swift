import Foundation
import Testing
@testable import lily

@MainActor
struct DiscoverGroupsViewModelTests {
    private let harness = GroupHarness()
    private let sleep = HeldSleep()

    private func makeViewModel() -> DiscoverGroupsViewModel {
        DiscoverGroupsViewModel(changes: harness.changes,
                                repository: harness.repository,
                                identity: harness.identity,
                                locationService: harness.location,
                                errorCenter: harness.errorCenter,
                                recorder: harness.recorder,
                                logger: harness.logger) { [sleep] in try await sleep.sleep(for: $0) }
    }

    /// "Joined" on a card is the server's answer for one caller, so another caller earns a new search.
    @Test func searchesAgainForAnotherCaller() async {
        harness.repository.result = .success([.fixture(id: "p")])
        let viewModel = makeViewModel()

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 1)

        harness.identity.currentUserID = "someone-else"
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes.count == 2)
    }

    /// Discover is for guests too: nothing here asks who the caller is.
    @Test func loadsOnceAndAgainOnRefreshForGuests() async {
        harness.identity.currentUserID = nil
        harness.repository.result = .success([.fixture(id: "p")])
        let viewModel = makeViewModel()

        await viewModel.loadIfStale()
        await viewModel.loadIfStale()
        #expect(harness.repository.requestedScopes == [.discover(query: nil, type: nil)])
        #expect(viewModel.groups.map(\.id) == ["p"] && viewModel.hasSearched && !viewModel.nothingMatched)

        await viewModel.refresh()
        #expect(harness.repository.requestedScopes.count == 2)
    }

    /// The empty state waits for the first answer; a later search over a page already shown is not an initial load.
    @Test func theEmptyStateWaitsForTheFirstAnswer() async {
        harness.repository.result = .success([])
        harness.repository.holdsRequests = true
        let viewModel = makeViewModel()
        #expect(!viewModel.isInitialLoad && !viewModel.nothingMatched, "nothing asked yet")

        let appearance = Task { await viewModel.loadIfStale() }
        await settle(until: { harness.repository.requestedScopes.count == 1 })
        #expect(viewModel.isInitialLoad && !viewModel.nothingMatched)

        harness.repository.releaseRequests()
        await appearance.value
        #expect(!viewModel.isInitialLoad && viewModel.nothingMatched)

        harness.repository.holdsRequests = true
        let refresh = Task { await viewModel.refresh() }
        await settle(until: { harness.repository.requestedScopes.count == 2 })
        #expect(viewModel.isLoading && !viewModel.isInitialLoad && !viewModel.nothingMatched)
        harness.repository.releaseRequests()
        await refresh.value
    }

    @Test func typingWaitsForTheDebounceAndSendsTheLastQuery() async {
        harness.repository.result = .success([])
        let viewModel = makeViewModel()

        viewModel.query = "ber"
        await settle(until: { sleep.requested.count == 1 })
        #expect(sleep.requested == [AppConfig.Groups.searchDebounce])
        #expect(harness.repository.requestedScopes.isEmpty)

        viewModel.query = "berl"
        await settle(until: { sleep.requested.count == 2 })
        sleep.release()
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        #expect(harness.repository.requestedScopes == [.discover(query: "berl", type: nil)])
        #expect(viewModel.nothingMatched)
    }

    /// The cap counts UTF-16 units like Laurel's `@Size`: letters up to the limit plus an emoji would be one character
    /// over on the wire and earn a 400 on every keystroke, so the emoji is dropped.
    @Test func theQueryIsTrimmedCappedAndAbsentWhenBlank() {
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()

        viewModel.typeFilter = .football
        await settle(until: { harness.repository.requestedScopes.count == 1 })

        #expect(sleep.requested.isEmpty)
        #expect(harness.repository.requestedScopes == [.discover(query: nil, type: .football)])
        #expect(viewModel.groups.map(\.id) == ["f"])
    }

    /// Statistics carry whether a name was typed and how many came back; the name itself stays on the device.
    @Test func searchRecordsWhetherSomethingWasTypedAndTheCount() async {
        harness.repository.result = .success([.fixture(id: "a"), .fixture(id: "b")])
        let viewModel = makeViewModel()

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
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()
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
        let viewModel = makeViewModel()

        await viewModel.search()

        #expect(harness.presentedError == .groupsUnavailable)
        #expect(harness.logs(.error).count == 1)
        #expect(!viewModel.isLoading)
    }

    /// Cancelling a pending search ends its wait and sends nothing.
    @Test func cancelStopsAPendingSearch() async {
        let viewModel = makeViewModel()
        viewModel.query = "x"
        await settle(until: { sleep.requested.count == 1 })

        viewModel.cancel()
        await settle(until: { sleep.held.isEmpty })
        for _ in 0..<10 { await Task.yield() }

        #expect(harness.repository.requestedScopes.isEmpty && sleep.held.isEmpty)
    }
}
