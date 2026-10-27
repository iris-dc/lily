import Foundation

/// Polls: the "+" menu's item, the creation sheet, the bubble and the voters.
nonisolated extension AppBranding.Chat {
    enum Polls {
        static var poll: String { localized("Poll") }
        static var newPoll: String { localized("New poll") }
        static var question: String { localized("Question") }
        static var askAQuestion: String { localized("Ask a question") }
        static var options: String { localized("Options") }
        static func option(_ number: Int) -> String { localized("Option \(number)") }
        static var addOption: String { localized("Add an option") }
        static var removeOption: String { localized("Remove option") }
        static var anonymousVoting: String { localized("Anonymous voting") }
        static var multipleAnswers: String { localized("Multiple answers") }
        static var anonymousPoll: String { localized("Anonymous poll") }
        static var publicPoll: String { localized("Public poll") }
        static var vote: String { localized("Vote") }
        static var retractVote: String { localized("Retract vote") }
        static var viewVotes: String { localized("View votes") }
        static var votes: String { localized("Votes") }
        static var noVotesYet: String { localized("No votes yet") }
        static var nobodyYet: String { localized("Nobody yet") }
        /// "4 votes", counting voters (plural variations in the catalog).
        static func voterCount(_ count: Int) -> String { localized("\(count) votes") }
        /// The quote of a poll in a reply or a pin: "Poll: Which court?".
        static func quoted(_ question: String) -> String { localized("Poll: \(question)") }
        static var chosen: String { localized("Your vote") }
    }
}
