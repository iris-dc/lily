import Foundation
import Testing
@testable import lily

/// How a poll's option is drawn before and after the caller voted.
@MainActor
struct PollOptionDisplayTests {
    @Test func beforeVotingTheCallersTicksMarkAndNoShareShows() {
        let poll = Poll.fixture(allowsMultipleAnswers: true)
        let ticked = PollOptionDisplay(poll.options[0], in: poll, ticked: ["0"])
        let plain = PollOptionDisplay(poll.options[1], in: poll, ticked: ["0"])

        #expect(ticked.isMarked && !ticked.showsShare)
        #expect(!plain.isMarked && !plain.showsShare)
    }

    @Test func onceVotedThePicksMarkAndEveryShareShows() {
        let poll = Poll.fixture(myVotes: ["1"])
        let mine = PollOptionDisplay(poll.options[1], in: poll, ticked: ["0"])
        let other = PollOptionDisplay(poll.options[0], in: poll, ticked: ["0"])

        #expect(mine.isMarked && mine.showsShare && mine.share == poll.share(of: poll.options[1]))
        #expect(!other.isMarked && other.showsShare, "a tick left over from before the vote no longer marks")
    }

    @Test func aRetractionShowsNoShareAndUnmarksTheOldPick() {
        let voted = Poll.fixture(myVotes: ["1"])
        let retracted = voted.voting([])
        let display = PollOptionDisplay(retracted.options[1], in: retracted, ticked: [])

        #expect(!display.isMarked && !display.showsShare)
    }

    @Test func aPollWithNoVotersHasZeroShares() {
        let poll = Poll.fixture(myVotes: ["0"], votes: [0, 0], totalVoters: 0)

        #expect(PollOptionDisplay(poll.options[0], in: poll, ticked: []).share == 0)
        #expect(PollOptionDisplay(poll.options[1], in: poll, ticked: []).share == 0)
    }
}
