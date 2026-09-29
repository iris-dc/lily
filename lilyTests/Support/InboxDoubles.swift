import Foundation
@testable import lily

/// Scriptable `InboxRepository`: pages answer from a queue (an empty page once it runs dry), accept and decline answer
/// the stored item with its status flipped, and every call is recorded. `holdsRequests` parks every request until
/// released, so a test can act while one is observably in flight.
@MainActor
final class FakeInboxRepository: InboxRepository {
    struct PageRequest: Equatable {
        let before: String?
        let limit: Int
    }

    /// Dequeued one per page request.
    var pages: [InboxPage] = []
    /// Thrown by every page request when set.
    var pageError: (any Error)?
    /// What accept and decline answer from; an id not held answers a fixture invite of that id.
    var items: [InboxItem] = []
    /// The group an accept answers, membership included.
    var acceptedGroup: SportGroup = .fixture(id: "g3", name: "Climbing Buddies", visibility: .private, role: .member)
    /// Thrown by the next accepts, one each, before `acceptError` is consulted: a `.tryAgain` that a repeat gets past.
    var transientAcceptErrors: [AppError] = []
    var acceptError: (any Error)?
    var declineError: (any Error)?
    var readMarkerError: (any Error)?
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    /// When accept and decline stamp their answer.
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let hold = RequestHold()
    private(set) var pageRequests: [PageRequest] = []
    private(set) var acceptedItemIDs: [String] = []
    private(set) var declinedItemIDs: [String] = []
    private(set) var readMarks: [String] = []

    func page(before itemID: String?, limit: Int) async throws -> InboxPage {
        pageRequests.append(PageRequest(before: itemID, limit: limit))
        try await holdIfRequested()
        if let pageError { throw pageError }
        guard !pages.isEmpty else { return InboxPage(items: []) }
        return pages.removeFirst()
    }

    func markRead(itemID: String) async throws -> String {
        readMarks.append(itemID)
        try await holdIfRequested()
        if let readMarkerError { throw readMarkerError }
        return itemID
    }

    func accept(itemID: String) async throws -> InviteAcceptance {
        acceptedItemIDs.append(itemID)
        try await holdIfRequested()
        if !transientAcceptErrors.isEmpty { throw transientAcceptErrors.removeFirst() }
        if let acceptError { throw acceptError }
        return InviteAcceptance(item: stored(itemID).responding(.accepted, at: now), group: acceptedGroup)
    }

    func decline(itemID: String) async throws -> InboxItem {
        declinedItemIDs.append(itemID)
        try await holdIfRequested()
        if let declineError { throw declineError }
        return stored(itemID).responding(.declined, at: now)
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    /// A caller cancelled while held learns of it once the hold lifts, as a URLSession task does.
    private func holdIfRequested() async throws {
        await hold.wait()
        try Task.checkCancellation()
    }

    private func stored(_ itemID: String) -> InboxItem {
        items.first { $0.id == itemID } ?? .invite(id: itemID)
    }
}
