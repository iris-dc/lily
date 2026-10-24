import Foundation
import Testing
@testable import lily

/// A poll's local arithmetic, the draft's rules (the backend's limits) and the wire shapes of the contract.
@MainActor
struct PollTests {
    @Test func aFirstVoteAddsAVoterAndItsOption() {
        let voted = Poll.fixture().voting(["1"])

        #expect(voted.options.map(\.votes) == [3, 2] && voted.totalVoters == 5 && voted.myVotes == ["1"])
    }

    @Test func changingTheVoteMovesItAndTakingItBackRemovesTheVoter() {
        let changed = Poll.fixture(myVotes: ["0"]).voting(["1"])
        let retracted = Poll.fixture(myVotes: ["0"]).voting([])

        #expect(changed.options.map(\.votes) == [2, 2] && changed.totalVoters == 4)
        #expect(retracted.options.map(\.votes) == [2, 1] && retracted.totalVoters == 3 && !retracted.hasVoted)
    }

    @Test func multipleAnswersCountTheVoterOnceInOptionOrder() {
        let voted = Poll.fixture(allowsMultipleAnswers: true, votes: [0, 0, 0], totalVoters: 0).voting(["2", "0"])

        #expect(voted.options.map(\.votes) == [1, 0, 1] && voted.totalVoters == 1 && voted.myVotes == ["0", "2"])
        #expect(voted.share(of: voted.options[0]) == 1 && voted.share(of: voted.options[1]) == 0)
    }

    @Test func aDraftNeedsAQuestionAndTwoDistinctOptions() {
        var draft = PollDraft()
        draft.question = "  Which court?  "
        draft.options = ["Court 1", " "]
        #expect(!draft.isValid, "one filled option")

        draft.options = ["Court 1", "Court 1 "]
        #expect(!draft.isValid, "the same option twice")

        draft.options = ["Court 1", " Court 3", ""]
        #expect(draft.isValid)
        #expect(draft.payload == PollPayload(question: "Which court?",
                                             options: ["Court 1", "Court 3"],
                                             isAnonymous: true,
                                             allowsMultipleAnswers: false))
        #expect(draft.preview.options.map(\.id) == ["0", "1"] && draft.preview.totalVoters == 0)
    }

    @Test func aDraftKeepsToTheBackendsLimits() {
        var draft = PollDraft()
        draft.question = String(repeating: "q", count: AppConfig.Chat.Polls.questionMaxLength + 1)
        draft.options = ["a", "b"]
        #expect(!draft.isValid)

        draft.question = "Which?"
        draft.options = (0...AppConfig.Chat.Polls.maxOptions).map(String.init)
        #expect(!draft.isValid && !draft.canAddOption)
    }

    @Test func aPollMessageDecodesWithItsPollAndIsAMembersBubble() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.pollMessage)

        #expect(message.kind == .poll && !message.isSystem && message.text == nil)
        #expect(message.poll == .fixture(myVotes: ["0"]))
        #expect(message.markingDeleted().poll == nil)
    }

    @Test func aPageCarriesItsPinsAndPollRevisionAndAnOlderPageReadsAsNone() throws {
        let page = try ContractSamples.decode(MessagePage.self, from: ContractSamples.pagedPollsAndPins)
        let older = try ContractSamples.decode(MessagePage.self, from: ContractSamples.messagePage)

        #expect(page.pollRevision == 12 && page.pins.map(\.messageId) == ["01J8ZK7Q9X2M4N6P8R0T2V4W6Y"])
        #expect(page.items.last?.kind == .messagePinned && page.items.last?.replyTo?.excerpt == "Thursday works for me.")
        #expect(older.pollRevision == 0 && older.pins.isEmpty)
    }

    @Test func theAnswersOfTheRoutesDecode() throws {
        let vote = try ContractSamples.decode(VoteResult.self, from: ContractSamples.voteResult)
        let states = try ContractSamples.decode(PollStates.self, from: ContractSamples.pollStates)
        let voters = try ContractSamples.decode(PollVoters.self, from: ContractSamples.pollVoters)
        let pins = try ContractSamples.decode(PinList.self, from: ContractSamples.pinList)

        #expect(vote.pollRevision == 12 && vote.poll.myVotes == ["0"])
        #expect(states.items.map(\.messageId) == ["01J8ZK7Q9X2M4N6P8R0T2V4W72"])
        #expect(voters.options.map { $0.voters.map(\.name) } == [["Jonas"], []])
        #expect(pins.pins.first?.quote.senderName == "Marta" && pins.channelEpoch == 3)
    }

    @Test func aPollSendsAloneAsTheContractShowsIt() throws {
        var draft = MessageDraft(clientMessageID: "c-1")
        draft.text = "ignored"
        draft.poll = PollDraft(question: "Which evening suits you?",
                               options: ["Tuesday", "Thursday"],
                               isAnonymous: true,
                               allowsMultipleAnswers: false)

        let sent = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.payload)) as? NSDictionary
        let contract = try JSONSerialization.jsonObject(with: Data(ContractSamples.sendPollBody.utf8)) as? NSDictionary
        #expect(sent == contract)
        #expect(draft.isValid)
    }

    @Test func aPollsQuoteIsItsQuestion() throws {
        let message = try ContractSamples.decode(ChatMessage.self, from: ContractSamples.pollMessage)

        #expect(ReplyQuote(quoting: message, senderName: "Marta").excerpt == "Which evening suits you?")
    }
}
