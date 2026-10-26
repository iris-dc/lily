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
}
