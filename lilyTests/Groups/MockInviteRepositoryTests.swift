import Foundation
import Testing
@testable import lily

/// The mock's behaviour the UI tests and previews lean on: who can be invited into which fixture group, and the
/// backend's refusals.
@MainActor
struct MockInviteRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let padel = MockGroupFixtures.padelID
    private let kickers = MockGroupFixtures.kickersID
    private let marta = MockGroupFixtures.memberID(for: "Marta")

    private func makeRepository() -> MockInviteRepository {
        let groups = MockGroupRepository(identity: identity, logger: logger) { now }
        return MockInviteRepository(groups: groups, identity: identity, logger: logger) { now }
    }

    /// Padel's candidates are the other two rosters, by name; Padel's own members and its banned row are out.
    @Test func candidatesAreTheOtherRostersMinusTheTargetsOwn() async throws {
        let candidates = try await makeRepository().candidates(groupID: padel)

        #expect(candidates.map(\.displayName) == ["Aiko", "Ayşe", "Dev", "Jonas", "Marta", "Noor", "Sam"])
        #expect(candidates.allSatisfy { $0.via == .group && !$0.isInvited })
        #expect(candidates.first { $0.userId == marta }?.viaName == "Kreuzberg Kickers")
        #expect(candidates.first { $0.displayName == "Aiko" }?.viaName == "Tempelhof Runners")
        #expect(!candidates.contains { ["Tom", "Ines", "Luca", "Priya"].contains($0.displayName) })
        #expect(!candidates.contains { $0.userId == TestFixtures.user.id })
    }

    /// Someone met only at a game comes in through the game; a group's own members never do, whatever they hosted.
    @Test func hostsOfTheMockGamesComeInThroughTheirGame() async throws {
        let candidates = try await makeRepository().candidates(groupID: kickers)

        let priya = try #require(candidates.first { $0.displayName == "Priya" })
        #expect(priya.via == .event && priya.viaName == "Sunrise yoga" && priya.caption == "Played Sunrise yoga")
        #expect(candidates.first { $0.displayName == "Tom" }?.viaName == "Sunday Padel Crew")
        #expect(!candidates.contains { $0.displayName == "Marta" || $0.displayName == "Dev" })
        #expect(candidates.map(\.displayName) == candidates.map(\.displayName).sorted())
    }

    @Test func invitingMarksTheCandidateInvitedAndReplaysTheSameInvite() async throws {
        let repository = makeRepository()

        let sent = try await repository.invite(groupID: padel, userID: marta)

        #expect(sent.groupId == padel && sent.inviteeUserId == marta && sent.inviteeName == "Marta")
        #expect(sent.status == .pending && sent.createdAt == now)
        #expect(sent.expiresAt == now.addingTimeInterval(AppConfig.Inbox.mockInviteExpiry))
        #expect(try await repository.candidates(groupID: padel).first { $0.userId == marta }?.isInvited == true)
        #expect(try await repository.candidates(groupID: kickers).allSatisfy { !$0.isInvited }, "an invite is per group")
        #expect(try await repository.invite(groupID: padel, userID: marta) == sent, "a repeat answers the same invite")
        #expect(logger.messages(in: .groups, at: .info).contains("Mock invite \(sent.id) into group \(padel) sent to \(marta)"))
    }

    @Test func theBackendsRefusals() async {
        let repository = makeRepository()

        await #expect(throws: AppError.alreadyMember) {
            try await repository.invite(groupID: padel, userID: TestFixtures.user.id)
        }
        await #expect(throws: AppError.alreadyMember) {
            try await repository.invite(groupID: padel, userID: MockGroupFixtures.memberID(for: "Tom"))
        }
        await #expect(throws: AppError.cannotInvite) {
            try await repository.invite(groupID: padel, userID: MockGroupFixtures.memberID(for: "Priya"))
        }
        await #expect(throws: AppError.userNotFound) { try await repository.invite(groupID: padel, userID: "nobody") }
        await #expect(throws: AppError.notAMember) { try await repository.candidates(groupID: MockGroupFixtures.basketballID) }
        await #expect(throws: AppError.groupNotFound) { try await repository.candidates(groupID: MockGroupFixtures.climbingID) }
    }

    @Test func guestsCanNeitherListNorInvite() async {
        identity.currentUserID = nil
        let repository = makeRepository()

        await #expect(throws: AppError.sessionExpired) { try await repository.candidates(groupID: padel) }
        await #expect(throws: AppError.sessionExpired) { try await repository.invite(groupID: padel, userID: marta) }
    }
}
