import Foundation
import Testing
@testable import lily

/// Voting shows at once and the answer replaces it; a refusal brings back the poll as it was and reaches the popup;
/// a lost answer asks the poll's state before deciding; a poll is sent like a message, in group chats only.
@MainActor
struct ChatViewModelPollTests {
    private let group = SportGroup.fixture(id: "g", channelEpoch: 1, role: .member)
    private let poll = ChatMessage.pollFixture(id: "m1")

    private func makeChat(_ group: SportGroup? = nil) async -> (RealtimeHarness, ChatViewModel) {
        let group = group ?? self.group
        let harness = RealtimeHarness()
        harness.groups.result = .success([group])
        harness.cache.store(.fixture(groupID: group.id, messages: [.pollFixture(id: "m1", groupID: group.id)]), for: group.id)
        await harness.connect()
        return (harness, harness.makeChatViewModel(for: group))
    }

    @Test func aVoteShowsAtOnceAndTheAnswerReplacesIt() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.holdsRequests = true
        let answered = Poll.fixture(myVotes: ["1"], votes: [3, 4], totalVoters: 7)
        harness.chat.polls.voteResults = [.success(VoteResult(messageId: "m1", poll: answered, pollRevision: 1))]

        let vote = Task { await viewModel.vote(in: poll, for: ["1"]) }
        await settle(until: { harness.chat.isHolding })
        #expect(viewModel.room.messages.first?.poll?.myVotes == ["1"], "shown before the answer")
        #expect(viewModel.room.messages.first?.poll?.totalVoters == 5)

        harness.chat.releaseRequests()
        await vote.value
        #expect(viewModel.room.messages.first?.poll == answered && viewModel.room.pollRevision == 1)
        #expect(harness.chatLogs(.info).mentioning(["Vote of 1 options", "m1"]).count == 1)
    }

    @Test func aRefusedVoteBringsThePollBackAndReachesThePopup() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.voteResults = [.failure(AppError.notAPoll)]

        await viewModel.vote(in: poll, for: ["0"])

        #expect(viewModel.room.messages.first?.poll == .fixture())
        #expect(harness.errorCenter.current?.error == .notAPoll)
        #expect(harness.chatLogs(.warning).mentioning(["Voting failed"]).count == 1, "a refusal the room expects")
    }

    /// The backend commits before it answers: the poll's state says the vote is in, so no popup.
    @Test func aLostAnswerWhoseVoteLandedShowsNoPopup() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.voteResults = [.failure(AppError.network)]
        let landed = Poll.fixture(myVotes: ["1"], votes: [3, 2], totalVoters: 5)
        harness.chat.polls.pollStates = [.success(PollStates(items: [PollState(messageId: "m1", poll: landed)], pollRevision: 3))]

        await viewModel.vote(in: poll, for: ["1"])

        #expect(viewModel.room.messages.first?.poll == landed && harness.errorCenter.current == nil)
    }

    @Test func aLostAnswerWhoseVoteDidNotLandBringsThePollBack() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.voteResults = [.failure(AppError.network)]
        let unchanged = PollStates(items: [PollState(messageId: "m1", poll: .fixture())], pollRevision: 0)
        harness.chat.polls.pollStates = [.success(unchanged)]

        await viewModel.vote(in: poll, for: ["1"])

        #expect(viewModel.room.messages.first?.poll == .fixture() && harness.errorCenter.current?.error == .network)
    }

    @Test func takingTheVoteBackSendsNoOptions() async {
        let (harness, viewModel) = await makeChat()
        harness.chat.polls.voteResults = [.success(VoteResult(messageId: "m1", poll: .fixture(), pollRevision: 1))]
        viewModel.mutateRoom { $0.applyPoll(messageID: "m1", poll: .fixture(myVotes: ["0"])) }
        #expect(viewModel.canRetractVote(in: poll))

        await viewModel.retractVote(in: poll)

        #expect(harness.chat.polls.votes.map(\.optionIDs) == [[]] && !viewModel.canRetractVote(in: poll))
    }

    @Test func aPollIsSentAloneThroughThePendingBubble() async throws {
        let (harness, viewModel) = await makeChat()
        let draft = PollDraft(question: "Which court?", options: ["1", "3"], isAnonymous: false, allowsMultipleAnswers: true)

        await viewModel.sendPoll(draft)

        let sent = try #require(harness.chat.sentDrafts.first)
        #expect(sent.poll == draft && sent.payload.text == nil && sent.payload.poll?.isAnonymous == false)
    }

    @Test func pollsAreForGroupChatsOnly() async {
        let (_, inGroup) = await makeChat()
        let (harness, inConversation) = await makeChat(.conversationFixture(id: "c"))

        #expect(inGroup.canCreatePolls && !inConversation.canCreatePolls)
        await inConversation.sendPoll(PollDraft(question: "Q", options: ["a", "b"]))
        #expect(harness.chat.sentDrafts.isEmpty)
    }

    @Test func theVotersOfAPublicPollAreAskedForAndARefusalReachesThePopup() async {
        let (harness, viewModel) = await makeChat()
        let voters = PollVoters(options: [.init(id: "0", voters: [.init(userId: "u-3", name: "Jonas")])])
        harness.chat.polls.voters = [.success(voters), .failure(AppError.pollAnonymous)]

        #expect(await viewModel.voters(of: poll) == voters)
        #expect(await viewModel.voters(of: poll) == nil && harness.errorCenter.current?.error == .pollAnonymous)
    }
}
