import Testing
@testable import lily

/// What a list segment shows, decided from the three facts a list view model knows.
struct ListStateTests {
    /// With nothing held, the first load's spinner comes first, whatever a load did.
    @Test func loadingWhileTheFirstLoadRunsOverNothing() {
        #expect(ListState(isInitialLoad: true, isEmpty: true, loadFailed: false) == .loading)
        #expect(ListState(isInitialLoad: true, isEmpty: true, loadFailed: true) == .loading)
    }

    /// The snapshot of the last answer is content on the first frame, through the first load.
    @Test func contentHeldThroughTheFirstLoadShows() {
        #expect(ListState(isInitialLoad: true, isEmpty: false, loadFailed: false) == .content)
        #expect(ListState(isInitialLoad: true, isEmpty: false, loadFailed: true) == .content)
    }

    @Test func emptyOnceAnAnswerHadNothing() {
        #expect(ListState(isInitialLoad: false, isEmpty: true, loadFailed: false) == .empty)
    }

    @Test func failedWhenNothingLoadedAndTheLoadFailed() {
        #expect(ListState(isInitialLoad: false, isEmpty: true, loadFailed: true) == .failed)
    }

    /// A failed reload keeps what is on screen rather than replacing it with the failed state.
    @Test func contentWhileThereIsSomethingToShowEvenAfterAFailedReload() {
        #expect(ListState(isInitialLoad: false, isEmpty: false, loadFailed: false) == .content)
        #expect(ListState(isInitialLoad: false, isEmpty: false, loadFailed: true) == .content)
    }
}
