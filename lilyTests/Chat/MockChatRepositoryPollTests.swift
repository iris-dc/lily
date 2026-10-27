import Foundation
import Testing
@testable import lily

/// The mock's polls and pins follow the backend's rules, and Sunday Padel Crew's room shows both from its fixtures.
extension MockChatRepositoryTests {
    private var padel: String { MockGroupFixtures.padelID }

    @Test func padelsRoomHoldsAPublicPollAndAPinWithItsNote() async throws {
        let page = try await makeRepository().newest(groupID: padel)

        let poll = try #require(page.items.first { $0.kind == .poll }?.poll)
        #expect(!poll.isAnonymous && poll.totalVoters == 3 && !poll.hasVoted)
        let note = try #require(page.items.first { $0.kind == .messagePinned })
        #expect(page.pins.map(\.messageId) == [note.replyTo?.messageId])
        let created = page.items.contains { $0.kind == .eventCreated } ? 1 : 0
        #expect(page.items.count == AppConfig.Chat.mockMessagesPerRoom + created, "the fixtures replace rows, add none")
    }

    @Test func aVoteReplacesTheCallersChoiceAndMovesTheRevision() async throws {
        let repository = makeRepository()
        let pollID = try #require(try await repository.newest(groupID: padel).items.first { $0.kind == .poll }?.id)

        let first = try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["1"])
        let second = try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["0"])

        #expect(first.poll.myVotes == ["1"] && first.pollRevision == 1)
        #expect(second.poll.options.map(\.votes) == [3, 0, 1] && second.pollRevision == 2)
        #expect(try await repository.newer(groupID: padel, after: "").pollRevision == 2)
        let voters = try await repository.voters(groupID: padel, messageID: pollID)
        #expect(voters.options.first?.voters.map(\.name) == ["Jonas", "Ayşe", "You"])
    }

    @Test func theSameVoteAgainChangesNothing() async throws {
        let repository = makeRepository()
        let pollID = try #require(try await repository.newest(groupID: padel).items.first { $0.kind == .poll }?.id)

        let first = try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["1"])
        let again = try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["1"])

        #expect(again == first, "the same choice answers the current state and moves no revision")
    }

    @Test func theVotersOfAnAnonymousPollOrOfANonPollAreRefused() async throws {
        let repository = makeRepository()
        var draft = MessageDraft()
        draft.poll = PollDraft(question: "Which court?", options: ["1", "3"])
        let anonymous = try await repository.send(groupID: padel, draft)
        let textID = try #require(try await repository.newest(groupID: padel).items.first { $0.kind == .text }?.id)

        await #expect(throws: AppError.pollAnonymous) {
            try await repository.voters(groupID: padel, messageID: anonymous.message.id)
        }
        await #expect(throws: AppError.notAPoll) {
            try await repository.voters(groupID: padel, messageID: textID)
        }
    }

    @Test func unpinningWhatIsNotPinnedAnswersTheListUnchanged() async throws {
        let repository = makeRepository()
        let before = try await repository.newest(groupID: padel).pins

        let after = try await repository.unpin(groupID: padel, messageID: "not-a-pin")

        #expect(after.pins == before && !before.isEmpty)
    }

    @Test func aVoteOutsideTheRulesIsRefused() async throws {
        let repository = makeRepository()
        let page = try await repository.newest(groupID: padel)
        let pollID = try #require(page.items.first { $0.kind == .poll }?.id)
        let textID = try #require(page.items.first { $0.kind == .text }?.id)

        await #expect(throws: AppError.voteFailed) {
            try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["0", "1"])
        }
        await #expect(throws: AppError.voteFailed) {
            try await repository.vote(groupID: padel, messageID: pollID, optionIDs: ["7"])
        }
        await #expect(throws: AppError.notAPoll) {
            try await repository.vote(groupID: padel, messageID: textID, optionIDs: ["0"])
        }
    }

    @Test func aPollGoesIntoAGroupButNotAConversation() async throws {
        let repository = makeRepository()
        var draft = MessageDraft()
        draft.poll = PollDraft(question: "Which court?", options: ["1", "3"])

        let sent = try await repository.send(groupID: padel, draft)
        #expect(sent.message.kind == .poll && sent.message.poll?.options.map(\.text) == ["1", "3"])

        await #expect(throws: AppError.pollsNotAllowed) {
            try await repository.send(groupID: MockGroupFixtures.martaConversationID, draft)
        }
    }

    @Test func anAdminPinsAndThePinPostsItsNote() async throws {
        let repository = makeRepository()
        let page = try await repository.newest(groupID: padel)
        let target = try #require(page.items.last { $0.kind == .text })

        let pinned = try await repository.pin(groupID: padel, messageID: target.id)
        let again = try await repository.pin(groupID: padel, messageID: target.id)

        #expect(pinned.pins.last?.messageId == target.id && again.pins == pinned.pins, "twice is once")
        let after = try await repository.newer(groupID: padel, after: page.items.last?.id ?? "")
        #expect(after.items.filter { $0.kind == .messagePinned }.map { $0.replyTo?.messageId } == [target.id])

        let unpinned = try await repository.unpin(groupID: padel, messageID: target.id)
        #expect(!unpinned.pins.contains { $0.messageId == target.id })
    }

    @Test func aPinOutsideTheRulesIsRefused() async throws {
        let repository = makeRepository()
        let kickersPage = try await repository.newest(groupID: kickers)
        let padelPage = try await repository.newest(groupID: padel)
        let note = try #require(padelPage.items.first { $0.isSystem })

        await #expect(throws: AppError.insufficientRole, "a plain member of Kreuzberg Kickers") {
            try await repository.pin(groupID: kickers, messageID: kickersPage.items[0].id)
        }
        await #expect(throws: AppError.notPinnable) {
            try await repository.pin(groupID: padel, messageID: note.id)
        }
    }

    @Test func deletingAPinnedMessageUnpinsIt() async throws {
        let repository = makeRepository()
        let pinnedID = try #require(try await repository.newest(groupID: padel).pins.first?.messageId)

        _ = try await repository.delete(groupID: padel, messageID: pinnedID)

        #expect(try await repository.newest(groupID: padel).pins.isEmpty)
    }
}
