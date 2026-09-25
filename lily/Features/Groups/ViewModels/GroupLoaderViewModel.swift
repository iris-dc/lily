import Foundation
import Observation

/// Fetches the group behind a reference (an event's "Hosted in" badge) before the detail can show it.
@Observable
final class GroupLoaderViewModel {
    enum State: Equatable {
        case loading
        case loaded(SportGroup)
        /// Deleted, or private and the caller is not in it: "This group is no longer available".
        case notFound
        /// Something else went wrong; the popup said what, the screen offers to try again.
        case failed
    }

    let ref: EventGroupRef
    private(set) var state: State = .loading

    private let repository: any GroupRepository
    private let errorCenter: ErrorCenter
    private let logger: any Logging

    init(ref: EventGroupRef, repository: any GroupRepository, errorCenter: ErrorCenter, logger: any Logging) {
        self.ref = ref
        self.repository = repository
        self.errorCenter = errorCenter
        self.logger = logger
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.group(id: ref.id))
        } catch AppError.groupNotFound {
            logger.info(.groups, "Group \(ref.id) is not available to the caller")
            state = .notFound
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.error(.groups, "Loading group \(ref.id) failed: \(error)")
            state = .failed
            errorCenter.report(error)
        }
    }
}
