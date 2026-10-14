import Foundation
import Testing
@testable import lily

/// The backend's refusals on the group routes a conversation and a tournament's room never take, and the replay of a
/// member's own join; a sibling file because the main suite's body is near the limit.
extension MockGroupRepositoryTests {
    /// Laurel's `requireGroupKind`: a conversation is left through the person, so every group route answers FORBIDDEN,
    /// while a member's join is replayed and the roster route stays open.
    @Test func aConversationRefusesGroupRoutes() async throws {
        let repository = makeRepository()
        let id = MockGroupFixtures.martaConversationID
        let marta = MockGroupFixtures.conversationCounterpart.userId

        await #expect(throws: AppError.insufficientRole) { try await repository.leave(id: id) }
        await #expect(throws: AppError.insufficientRole) { try await repository.update(id: id, .fixture()) }
        await #expect(throws: AppError.insufficientRole) { try await repository.delete(id: id) }
        await #expect(throws: AppError.insufficientRole) { try await repository.bans(id: id) }
        await #expect(throws: AppError.insufficientRole) { try await repository.unban(id: id, userID: marta) }

        let joined = try await repository.join(id: id)
        let stored = try await repository.group(id: id)
        #expect(joined.memberCount == 2)
        #expect(joined.role == .member)
        #expect(joined == stored, "a member joining again gets the conversation back unchanged")
        let roster = try await repository.members(id: id)
        #expect(roster.count == 2, "the roster route stays open")
    }

    /// A tournament's room is entered and left through the tournament: the group routes refuse its organiser (the
    /// room's owner) and its players alike, a member's join is replayed, and a private room is not there for an outsider.
    @Test func aTournamentRoomRefusesGroupRoutes() async throws {
        let repository = makeRepository()
        let cup = MockTournamentFixtures.kickersCupID
        let tableTennis = MockTournamentFixtures.tableTennisID
        let priya = MockGroupFixtures.memberID(for: "Priya")

        await #expect(throws: AppError.insufficientRole) { try await repository.leave(id: tableTennis) }
        await #expect(throws: AppError.insufficientRole) { try await repository.update(id: cup, .fixture()) }
        await #expect(throws: AppError.insufficientRole) { try await repository.delete(id: cup) }
        await #expect(throws: AppError.insufficientRole) { try await repository.bans(id: cup) }
        await #expect(throws: AppError.insufficientRole) { try await repository.unban(id: cup, userID: priya) }
        await #expect(throws: AppError.insufficientRole) { try await repository.remove(id: cup, userID: priya) }

        let before = try await repository.group(id: cup)
        let joined = try await repository.join(id: cup)
        #expect(joined.memberCount == before.memberCount, "the owner joining again is answered with the room as it is")
        let roster = try await repository.members(id: cup)
        #expect(roster.contains { $0.userId == priya }, "a refused removal leaves the roster alone")
        await #expect(throws: AppError.groupNotFound) { try await repository.join(id: MockTournamentFixtures.padelOpenID) }
    }

    /// Laurel's `replayOrThrowJoin`: a member joining again gets their group back before its visibility is judged.
    @Test func aMemberOfAPrivateGroupJoiningAgainGetsTheGroupBack() async throws {
        let repository = makeRepository()
        let id = MockGroupFixtures.padelID

        let joined = try await repository.join(id: id)

        let stored = try await repository.group(id: id)
        #expect(joined.role == .owner)
        #expect(joined.memberCount == 6)
        #expect(joined == stored)
        let mine = try await repository.groups(in: .mine, cursor: nil, near: nil).items
        #expect(mine.count == 6, "a replayed join adds nothing to Mine")
    }

    /// A target off the roster is nobody to remove or promote, whatever the caller may do there.
    @Test func aTargetOffTheRosterIsNotAMember() async throws {
        let repository = makeRepository()
        let runners = MockGroupFixtures.runnersID
        let marta = MockGroupFixtures.memberID(for: "Marta")
        let before = try await repository.members(id: runners)

        await #expect(throws: AppError.notAMember) { try await repository.remove(id: runners, userID: marta) }
        await #expect(throws: AppError.notAMember) {
            try await repository.setRole(id: MockGroupFixtures.padelID, userID: "nobody", .admin)
        }

        let group = try await repository.group(id: runners)
        let after = try await repository.members(id: runners)
        #expect(group.memberCount == 12)
        #expect(after.count == before.count)
    }

    /// Unbanning is an admin's: a plain member is refused.
    @Test func aMemberCannotUnban() async throws {
        let repository = makeRepository()
        let priya = MockGroupFixtures.memberID(for: "Priya")

        await #expect(throws: AppError.insufficientRole) {
            try await repository.unban(id: MockGroupFixtures.kickersID, userID: priya)
        }
    }
}
