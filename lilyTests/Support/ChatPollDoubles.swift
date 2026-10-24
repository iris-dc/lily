import Foundation
@testable import lily

/// The poll and pin routes of `FakeChatRepository`: each answers its queued results in turn (a failure is an error in
/// the queue), else a plain answer built from the call, and records the call. Votes and pins wait on the fake's hold.
@MainActor
final class FakePollRoutes {
    var voteResults: [Result<VoteResult, any Error>] = []
    var pollStates: [Result<PollStates, any Error>] = []
    var voters: [Result<PollVoters, any Error>] = []
    var pinLists: [Result<PinList, any Error>] = []
    private(set) var votes: [(messageID: String, optionIDs: [String])] = []
    private(set) var refreshes: [[String]] = []
    private(set) var voterRequests: [String] = []
    private(set) var pinned: [String] = []
    private(set) var unpinned: [String] = []

    func vote(_ messageID: String, _ optionIDs: [String]) throws -> VoteResult {
        votes.append((messageID, optionIDs))
        guard !voteResults.isEmpty else { throw AppError.voteFailed }
        return try voteResults.removeFirst().get()
    }

    func refresh(_ messageIDs: [String]) throws -> PollStates {
        refreshes.append(messageIDs)
        guard !pollStates.isEmpty else { return PollStates(items: [], pollRevision: 0) }
        return try pollStates.removeFirst().get()
    }

    func voters(of messageID: String) throws -> PollVoters {
        voterRequests.append(messageID)
        guard !voters.isEmpty else { throw AppError.pollAnonymous }
        return try voters.removeFirst().get()
    }

    func pin(_ messageID: String, unpinning: Bool) throws -> PinList {
        if unpinning { unpinned.append(messageID) } else { pinned.append(messageID) }
        guard !pinLists.isEmpty else { throw AppError.pinFailed }
        return try pinLists.removeFirst().get()
    }
}

extension FakeChatRepository {
    func vote(groupID: String, messageID: String, optionIDs: [String]) async throws -> VoteResult {
        onRequest()
        try await hold.waitOrThrow()
        return try polls.vote(messageID, optionIDs)
    }

    func polls(groupID: String, messageIDs: [String]) async throws -> PollStates {
        try polls.refresh(messageIDs)
    }

    func voters(groupID: String, messageID: String) async throws -> PollVoters {
        try polls.voters(of: messageID)
    }

    func pin(groupID: String, messageID: String) async throws -> PinList {
        try await hold.waitOrThrow()
        return try polls.pin(messageID, unpinning: false)
    }

    func unpin(groupID: String, messageID: String) async throws -> PinList {
        try await hold.waitOrThrow()
        return try polls.pin(messageID, unpinning: true)
    }
}
