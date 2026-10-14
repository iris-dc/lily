import Foundation
@testable import lily

/// Scriptable `UserRepository`: profiles answer from `profileResult`, conversations from `conversationResult`; every
/// call is recorded. `holdsRequests` parks every request until released.
@MainActor
final class FakeUserRepository: UserRepository, HoldsRequests {
    var profileResult: Result<UserProfile, AppError> = .success(.fixture())
    var conversationResult: Result<SportGroup, AppError> = .success(.conversationFixture())
    /// Thrown by the next conversation starts, one each, before `conversationResult` is consulted: a `.tryAgain` that a
    /// repeat gets past.
    var transientConversationErrors: [AppError] = []
    /// Thrown instead of a result when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    let hold = RequestHold()
    private(set) var requestedProfileIDs: [String] = []
    private(set) var conversationRequests: [String] = []

    func profile(userID: String) async throws -> UserProfile {
        requestedProfileIDs.append(userID)
        try await hold.waitOrThrow()
        if let thrownError { throw thrownError }
        return try profileResult.get()
    }

    func startConversation(with userID: String) async throws -> SportGroup {
        conversationRequests.append(userID)
        try await hold.waitOrThrow()
        if let thrownError { throw thrownError }
        if !transientConversationErrors.isEmpty { throw transientConversationErrors.removeFirst() }
        return try conversationResult.get()
    }
}
