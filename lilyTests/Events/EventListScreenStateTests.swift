import Testing
@testable import lily

struct EventListScreenStateTests {
    @Test func theFirstLoadOverNothingShowsTheSpinnerWhateverElseIsTrue() {
        for loadFailed in [false, true] {
            let state = EventListScreenState.resolve(isInitialLoad: true,
                                                     loadFailed: loadFailed,
                                                     hasEvents: false,
                                                     isEverythingFilteredOut: false)
            #expect(state == .loading, "loadFailed \(loadFailed)")
        }
    }

    /// The snapshot of the last answer shows through the first load, the filter judged as ever.
    @Test func eventsHeldThroughTheFirstLoadShow() {
        for loadFailed in [false, true] {
            let list = EventListScreenState.resolve(isInitialLoad: true,
                                                    loadFailed: loadFailed,
                                                    hasEvents: true,
                                                    isEverythingFilteredOut: false)
            let filtered = EventListScreenState.resolve(isInitialLoad: true,
                                                        loadFailed: loadFailed,
                                                        hasEvents: true,
                                                        isEverythingFilteredOut: true)
            #expect(list == .list && filtered == .filteredOut, "loadFailed \(loadFailed)")
        }
    }

    @Test func nothingLoadedAfterAFailureIsTheFailedState() {
        let state = EventListScreenState.resolve(isInitialLoad: false,
                                                 loadFailed: true,
                                                 hasEvents: false,
                                                 isEverythingFilteredOut: false)
        #expect(state == .failed)
    }

    @Test func nothingLoadedWithoutAFailureIsEmpty() {
        let state = EventListScreenState.resolve(isInitialLoad: false,
                                                 loadFailed: false,
                                                 hasEvents: false,
                                                 isEverythingFilteredOut: false)
        #expect(state == .empty)
    }

    @Test func eventsHiddenByTheFilterReadFilteredOut() {
        let state = EventListScreenState.resolve(isInitialLoad: false,
                                                 loadFailed: false,
                                                 hasEvents: true,
                                                 isEverythingFilteredOut: true)
        #expect(state == .filteredOut)
    }

    /// Content that is not the answer for the user's position (the snapshot, or an answer for none) and that the filter
    /// hides entirely is no verdict: the spinner, until the answer for the position lands.
    @Test func everythingFilteredOutWhileTheAnswerForThePositionIsOutIsLoading() {
        let waiting = EventListScreenState.resolve(isInitialLoad: false,
                                                   loadFailed: false,
                                                   hasEvents: true,
                                                   isEverythingFilteredOut: true,
                                                   awaitsAnswerForPosition: true)
        let showing = EventListScreenState.resolve(isInitialLoad: false,
                                                   loadFailed: false,
                                                   hasEvents: true,
                                                   isEverythingFilteredOut: false,
                                                   awaitsAnswerForPosition: true)
        #expect(waiting == .loading && showing == .list)
    }

    @Test func aFailedRefreshKeepsTheList() {
        let state = EventListScreenState.resolve(isInitialLoad: false,
                                                 loadFailed: true,
                                                 hasEvents: true,
                                                 isEverythingFilteredOut: false)
        #expect(state == .list)
    }

    @Test func aFailedRefreshWithEverythingFilteredOutStillOffersShowAll() {
        let state = EventListScreenState.resolve(isInitialLoad: false,
                                                 loadFailed: true,
                                                 hasEvents: true,
                                                 isEverythingFilteredOut: true)
        #expect(state == .filteredOut)
    }
}
