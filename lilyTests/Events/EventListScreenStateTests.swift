import Testing
@testable import lily

struct EventListScreenStateTests {
    @Test func theFirstLoadShowsTheSpinnerWhateverElseIsTrue() {
        for loadFailed in [false, true] {
            for hasEvents in [false, true] {
                for filteredOut in [false, true] {
                    let state = EventListScreenState.resolve(isInitialLoad: true,
                                                             loadFailed: loadFailed,
                                                             hasEvents: hasEvents,
                                                             isEverythingFilteredOut: filteredOut)
                    #expect(state == .loading, "loadFailed \(loadFailed), hasEvents \(hasEvents), filteredOut \(filteredOut)")
                }
            }
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
