import Foundation

/// What a list screen shows: the spinner before the first answer, the content whenever there is some, else why there
/// is none. Shared by the list view models (`listState`), so a segment drawing one branches on a single value. The
/// view models' own `isInitialLoad` rules are not identical (the events list also requires a load in flight), so the
/// first-load decision comes in as an input rather than being restated here.
nonisolated enum ListState: Equatable, Sendable {
    case loading
    case empty
    case failed
    case content

    /// A failed reload keeps what is on screen: `failed` is shown only while there is nothing to show instead.
    init(isInitialLoad: Bool, isEmpty: Bool, loadFailed: Bool) {
        if isInitialLoad {
            self = .loading
        } else if !isEmpty {
            self = .content
        } else {
            self = loadFailed ? .failed : .empty
        }
    }
}
