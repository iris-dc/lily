import Foundation

/// How one option of a poll is drawn: whether its ring is a tick and whether its share fills the pill. Before the caller
/// voted the tick is theirs to set (`ticked`, a poll with several answers collects them for Vote) and no share shows;
/// once they voted their picks are ticked and every option shows its share.
nonisolated struct PollOptionDisplay: Equatable, Sendable {
    let isMarked: Bool
    let showsShare: Bool
    /// The share of the voters who picked the option, 0 to 1; what the pill fills to once shown.
    let share: Double

    init(_ option: Poll.Option, in poll: Poll, ticked: Set<String>) {
        showsShare = poll.hasVoted
        isMarked = poll.hasVoted ? poll.myVotes.contains(option.id) : ticked.contains(option.id)
        share = poll.share(of: option)
    }
}
