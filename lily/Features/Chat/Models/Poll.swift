import Foundation

/// A poll as the backend answers it on a `poll` message: the question, its options with their counts, how it votes
/// and the caller's own choice (`myVotes`, empty before they voted). Option ids are the options' indices as strings,
/// fixed at creation. `totalVoters` counts people, so in a poll with multiple answers the votes add up to more.
nonisolated struct Poll: Hashable, Codable, Sendable {
    nonisolated struct Option: Identifiable, Hashable, Codable, Sendable {
        let id: String
        let text: String
        let votes: Int
    }

    let question: String
    let options: [Option]
    let isAnonymous: Bool
    let allowsMultipleAnswers: Bool
    let totalVoters: Int
    let myVotes: [String]

    var hasVoted: Bool { !myVotes.isEmpty }

    /// The share of the voters who picked `option`, from 0 to 1; 0 while nobody voted.
    func share(of option: Option) -> Double {
        totalVoters > 0 ? Double(option.votes) / Double(totalVoters) : 0
    }

    /// The poll as it reads once the caller's choice is `optionIDs` (empty takes the vote back): their old picks lose a
    /// vote, the new ones gain one, and the voters count them once. What the bubble shows before the backend answers.
    func voting(_ optionIDs: [String]) -> Poll {
        let old = Set(myVotes)
        let new = Set(optionIDs)
        let options = options.map { option in
            let change = (new.contains(option.id) ? 1 : 0) - (old.contains(option.id) ? 1 : 0)
            return Option(id: option.id, text: option.text, votes: max(0, option.votes + change))
        }
        let voterChange = (new.isEmpty ? 0 : 1) - (old.isEmpty ? 0 : 1)
        return Poll(question: question,
                    options: options,
                    isAnonymous: isAnonymous,
                    allowsMultipleAnswers: allowsMultipleAnswers,
                    totalVoters: max(0, totalVoters + voterChange),
                    myVotes: options.map(\.id).filter(new.contains))
    }
}

/// A poll being written: what the creation sheet holds and the send carries (`poll` in the payload). The texts are
/// trimmed when sent; the limits are the backend's (`AppConfig.Chat.Polls`).
nonisolated struct PollDraft: Hashable, Sendable {
    var question = ""
    var options = ["", ""]
    var isAnonymous = true
    var allowsMultipleAnswers = false

    private typealias Limits = AppConfig.Chat.Polls

    /// The options that will be sent: trimmed, blank ones left out.
    var filledOptions: [String] { options.compactMap(\.nonBlankTrimmed) }

    var canAddOption: Bool { options.count < Limits.maxOptions }

    var isValid: Bool {
        let question = question.trimmed
        let filled = filledOptions
        return !question.isEmpty && question.wireLength <= Limits.questionMaxLength
            && filled.count >= Limits.minOptions && filled.count <= Limits.maxOptions
            && filled.allSatisfy { $0.wireLength <= Limits.optionMaxLength }
            && Set(filled).count == filled.count
    }

    var payload: PollPayload {
        PollPayload(question: question.trimmed,
                    options: filledOptions,
                    isAnonymous: isAnonymous,
                    allowsMultipleAnswers: allowsMultipleAnswers)
    }

    /// The poll as its own pending bubble shows it: no votes yet.
    var preview: Poll {
        Poll(question: question.trimmed,
             options: filledOptions.enumerated().map { Poll.Option(id: String($0.offset), text: $0.element, votes: 0) },
             isAnonymous: isAnonymous,
             allowsMultipleAnswers: allowsMultipleAnswers,
             totalVoters: 0,
             myVotes: [])
    }
}

/// The `poll` of a send's body.
nonisolated struct PollPayload: Encodable, Equatable, Sendable {
    let question: String
    let options: [String]
    let isAnonymous: Bool
    let allowsMultipleAnswers: Bool
}

/// Body of `PUT /api/groups/{id}/messages/{messageId}/vote`; empty takes the vote back.
nonisolated struct VotePayload: Encodable, Equatable, Sendable {
    let optionIds: [String]
}

/// Answer of the vote: the poll's state with the caller's choice, and the room's poll revision after it.
nonisolated struct VoteResult: Hashable, Codable, Sendable {
    let messageId: String
    let poll: Poll
    let pollRevision: Int
}

/// One poll's current state, as `GET /api/groups/{id}/polls` lists them.
nonisolated struct PollState: Hashable, Codable, Sendable {
    let messageId: String
    let poll: Poll
}

/// Answer of `GET /api/groups/{id}/polls?ids=`: the live polls among the ids asked for, and the room's revision.
nonisolated struct PollStates: Hashable, Codable, Sendable {
    let items: [PollState]
    let pollRevision: Int
}

/// Who picked what in a public poll, every option present, voters in the order they voted.
nonisolated struct PollVoters: Hashable, Codable, Sendable {
    nonisolated struct Option: Identifiable, Hashable, Codable, Sendable {
        let id: String
        let voters: [Voter]
    }

    nonisolated struct Voter: Identifiable, Hashable, Codable, Sendable {
        let userId: String
        let name: String

        var id: String { userId }
    }

    let options: [Option]
}
