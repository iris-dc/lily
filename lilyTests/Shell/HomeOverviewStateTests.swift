import Testing
@testable import lily

struct HomeOverviewStateTests {
    /// An answered, empty list that did not fail: the shape most of Home's lists have for most callers.
    private func snapshot(isEmpty: Bool = true, hasAnswered: Bool = true, loadFailed: Bool = false) -> HomeListSnapshot {
        HomeListSnapshot(isEmpty: isEmpty, hasAnswered: hasAnswered, loadFailed: loadFailed)
    }

    @Test func nothingAnsweredYetIsLoading() {
        let state = HomeOverviewState.resolve(events: snapshot(hasAnswered: false),
                                              groups: snapshot(hasAnswered: false),
                                              tournaments: snapshot(hasAnswered: false))
        #expect(state == .loading)
    }

    @Test func anUnansweredListKeepsTheScreenLoadingWhileTheOthersAreEmpty() {
        let state = HomeOverviewState.resolve(events: snapshot(),
                                              groups: snapshot(),
                                              tournaments: snapshot(hasAnswered: false))
        #expect(state == .loading)
    }

    @Test func everyListEmptyAndAnsweredIsEmpty() {
        let state = HomeOverviewState.resolve(events: snapshot(), groups: snapshot(), tournaments: snapshot())
        #expect(state == .empty(loadFailed: false))
    }

    @Test(arguments: [true, false])
    func aFailedGamesOrGroupsLoadWithNothingElseIsTheFailedEmptyState(gamesFailed: Bool) {
        let state = HomeOverviewState.resolve(events: snapshot(loadFailed: gamesFailed),
                                              groups: snapshot(loadFailed: !gamesFailed),
                                              tournaments: snapshot())
        #expect(state == .empty(loadFailed: true))
    }

    @Test func aFailedTournamentsLoadAloneShowsTheSectionsWithItsNote() {
        let state = HomeOverviewState.resolve(events: snapshot(),
                                              groups: snapshot(),
                                              tournaments: snapshot(loadFailed: true))
        #expect(state == .sections(groups: .empty, tournaments: .failed, games: .empty))
    }

    @Test func contentInOneListShowsTheSectionsWithEachListsState() {
        let state = HomeOverviewState.resolve(events: snapshot(hasAnswered: false),
                                              groups: snapshot(isEmpty: false),
                                              tournaments: snapshot(hasAnswered: false))
        #expect(state == .sections(groups: .content, tournaments: nil, games: .loading))
    }

    @Test func aFailedRefreshBehindContentKeepsTheContent() {
        let state = HomeOverviewState.resolve(events: snapshot(isEmpty: false, loadFailed: true),
                                              groups: snapshot(),
                                              tournaments: snapshot())
        #expect(state == .sections(groups: .empty, tournaments: nil, games: .content))
    }

    @Test func aFailedGroupsLoadBesideGamesIsANoteNotTheEmptyScreen() {
        let state = HomeOverviewState.resolve(events: snapshot(isEmpty: false),
                                              groups: snapshot(loadFailed: true),
                                              tournaments: snapshot())
        #expect(state == .sections(groups: .failed, tournaments: nil, games: .content))
    }

    @Test func withGroupsOffTheGroupsListIsIgnored() {
        let empty = HomeOverviewState.resolve(events: snapshot(), groups: nil, tournaments: nil)
        #expect(empty == .empty(loadFailed: false))

        let games = HomeOverviewState.resolve(events: snapshot(isEmpty: false), groups: nil, tournaments: nil)
        #expect(games == .sections(groups: nil, tournaments: nil, games: .content))
    }

    @Test func aTournamentsListStillLoadingBehindContentStaysHidden() {
        let state = HomeOverviewState.resolve(events: snapshot(),
                                              groups: snapshot(isEmpty: false),
                                              tournaments: snapshot(hasAnswered: false))
        #expect(state == .sections(groups: .content, tournaments: nil, games: .empty))
    }
}
