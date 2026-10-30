import Foundation

/// What a list screen shows: the content whenever there is some (the last answer kept on the device included, while
/// the first load is still out), else the spinner before the first answer, else why there is none. The first-load rule
/// differs per list (the events list also requires a load in flight), so it comes in as an input.
nonisolated enum ListState: Equatable, Sendable {
    case loading
    case empty
    case failed
    case content

    /// A failed reload keeps what is on screen: `failed` is shown only while there is nothing to show instead.
    init(isInitialLoad: Bool, isEmpty: Bool, loadFailed: Bool) {
        if !isEmpty {
            self = .content
        } else if isInitialLoad {
            self = .loading
        } else {
            self = loadFailed ? .failed : .empty
        }
    }
}
