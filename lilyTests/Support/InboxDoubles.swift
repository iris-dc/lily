import Foundation
@testable import lily

/// Scriptable `InboxRepository`: pages answer from a queue (an empty page once it runs dry), accept and decline answer
/// the stored item with its status flipped and refuse an id they do not hold, and every call is recorded.
/// `holdsRequests` parks every request until released, so a test can act while one is observably in flight.
@MainActor
final class FakeInboxRepository: InboxRepository, HoldsRequests {
    struct PageRequest: Equatable {
        let before: String?
        let limit: Int
    }

    /// Dequeued one per page request.
    var pages: [InboxPage] = []
    /// Thrown by every page request when set.
    var pageError: (any Error)?
    /// What accept and decline answer from; an id not held is refused with `.inviteNotPending`, the backend's `INBOX_ITEM_NOT_FOUND`.
    var items: [InboxItem] = []
    /// The group an accept of a group invite answers, membership included; `nil` answers an acceptance naming neither
    /// a group nor a tournament, the drift case.
    var acceptedGroup: SportGroup? = .fixture(id: "g3", name: "Climbing Buddies", visibility: .private, role: .member)
    /// The tournament an accept of a tournament invite answers; one named after the invite's id when not set.
    var acceptedTournament: Tournament?
    /// Thrown by the next accepts, one each, before `acceptError` is consulted: a `.tryAgain` that a repeat gets past.
    var transientAcceptErrors: [AppError] = []
    var acceptError: (any Error)?
    var declineError: (any Error)?
    var readMarkerError: (any Error)?
    /// What `markRead` answers instead of echoing the sent id: the stored marker Laurel returns when another device
    /// read further.
    var readMarkerAnswer: String?
    /// When accept and decline stamp their answer.
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let hold = RequestHold()
    private(set) var pageRequests: [PageRequest] = []
    private(set) var acceptedItemIDs: [String] = []
    private(set) var declinedItemIDs: [String] = []
    private(set) var readMarks: [String] = []

    func page(before itemID: String?, limit: Int) async throws -> InboxPage {
        pageRequests.append(PageRequest(before: itemID, limit: limit))
        try await hold.waitOrThrow()
        if let pageError { throw pageError }
        guard !pages.isEmpty else { return InboxPage(items: []) }
        return pages.removeFirst()
    }

    func markRead(itemID: String) async throws -> String {
        readMarks.append(itemID)
        try await hold.waitOrThrow()
        if let readMarkerError { throw readMarkerError }
        return readMarkerAnswer ?? itemID
    }

    func accept(itemID: String) async throws -> InviteAcceptance {
        acceptedItemIDs.append(itemID)
        try await hold.waitOrThrow()
        if !transientAcceptErrors.isEmpty { throw transientAcceptErrors.removeFirst() }
        if let acceptError { throw acceptError }
        let item = try stored(itemID)
        if let invite = item.tournamentInvite {
            let tournament = acceptedTournament ?? .fixture(id: invite.tournamentId, name: invite.tournamentName)
            return InviteAcceptance(item: item.responding(.accepted, at: now), tournament: tournament)
        }
        return InviteAcceptance(item: item.responding(.accepted, at: now), group: acceptedGroup)
    }

    func decline(itemID: String) async throws -> InboxItem {
        declinedItemIDs.append(itemID)
        try await hold.waitOrThrow()
        if let declineError { throw declineError }
        return try stored(itemID).responding(.declined, at: now)
    }

    private func stored(_ itemID: String) throws -> InboxItem {
        guard let item = items.first(where: { $0.id == itemID }) else { throw AppError.inviteNotPending }
        return item
    }
}
