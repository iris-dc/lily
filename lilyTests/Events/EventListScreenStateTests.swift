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
