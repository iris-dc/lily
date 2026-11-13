import Foundation
import Testing
@testable import lily

/// The transcript's rows are rebuilt only when their inputs change: the memo is what keeps the body run of every
/// pinned frame from rebuilding an unchanged timeline.
@MainActor
struct ChatTimelineMemoTests {
    @Test func anUnchangedInputIsAnsweredWithoutARebuild() {
        var memo = ChatTimeline.Memo()
        let input = ChatTimeline.Input(messages: [.fixture(id: "m1"), .fixture(id: "m2")], currentUserID: "me")

        let first = memo.rows(for: input)
        let second = memo.rows(for: input)

        #expect(first == second && memo.builds == 1)
        #expect(first == ChatTimeline.rows(input), "the memo answers exactly what the timeline builds")
    }

    @Test func anyChangedInputRebuildsTheRows() {
        var memo = ChatTimeline.Memo()
        var input = ChatTimeline.Input(messages: [.fixture(id: "m1", senderUserID: "u-2")])
        _ = memo.rows(for: input)

        input.messages.append(.fixture(id: "m2", senderUserID: "u-2"))
        let grown = memo.rows(for: input)
        #expect(memo.builds == 2 && grown.contains { $0.id == "m2" })

        input.blockedUserIDs = ["u-2"]
        let blocked = memo.rows(for: input)
        #expect(memo.builds == 3 && !blocked.contains { $0.id == "m2" }, "a block re-filters at once")
    }
}
