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
    private let priya = MockGroupFixtures.memberID(for: "Priya")

    private func makeGroups() -> MockGroupRepository {
        MockGroupRepository(identity: identity, logger: logger) { now }
    }

    private func makeRepository(over groups: MockGroupRepository) -> MockInviteRepository {
        MockInviteRepository(groups: groups, identity: identity, logger: logger) { now }
    }

    private func makeRepository() -> MockInviteRepository {
        makeRepository(over: makeGroups())
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

    /// Priya's one live row among the caller's groups is the Kickers Cup's roster (her Padel row is banned): a
    /// tournament room is a shared group like any other.
    @Test func aPlayerKnownOnlyThroughATournamentRoomIsOfferedViaTheRoom() async throws {
        let candidates = try await makeRepository().candidates(groupID: kickers)

        let candidate = try #require(candidates.first { $0.userId == priya })
        #expect(candidate.via == .group && candidate.viaName == "Kickers Cup" && candidate.caption == "In Kickers Cup")
    }

    /// Someone on no roster of the caller's comes in through the game they host; a group's own members never do,
    /// whatever they hosted.
    @Test func aHostOnNoRosterComesInThroughTheirGame() async throws {
        let groups = makeGroups()
        let repository = makeRepository(over: groups)
        groups.leaveRoom(id: MockTournamentFixtures.kickersCupID, userID: priya)
        let feed = MockEventFixtures.make(now: now, count: AppConfig.Events.mockFeedSize)
        let hosted = try #require(feed.first { $0.hostName == "Priya" })

        let candidates = try await repository.candidates(groupID: kickers)

        let candidate = try #require(candidates.first { $0.userId == priya })
        #expect(candidate.via == .event && candidate.viaName == hosted.title)
        #expect(candidates.first { $0.displayName == "Tom" }?.viaName == "Sunday Padel Crew")
        #expect(!candidates.contains { $0.displayName == "Marta" || $0.displayName == "Dev" })
        #expect(candidates.map(\.displayName) == candidates.map(\.displayName).sorted())
    }

    /// The backend's rule: the rosters of the caller's non-direct groups come first (minus the target's own people and
    /// the caller), and the games fill in only whoever is on none of them.
    @Test func rostersComeFirstAndGamesFillInWhoIsOnNone() async throws {
        let groups = makeGroups()
        let repository = makeRepository(over: groups)
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items
        let shared = mine.filter { !$0.isDirect && $0.id != kickers }
        let liveMembers = shared.flatMap { group in groups.roster(of: group.id).filter { $0.role != .banned } }
        var rosterIDs = Set(liveMembers.map(\.userId))
        rosterIDs.subtract(groups.roster(of: kickers).map(\.userId))
        rosterIDs.remove(TestFixtures.user.id)

        let candidates = try await repository.candidates(groupID: kickers)

        #expect(!rosterIDs.isEmpty)
        #expect(candidates.filter { $0.via == .event }.allSatisfy { !rosterIDs.contains($0.userId) })
        #expect(candidates.filter { rosterIDs.contains($0.userId) }.allSatisfy { $0.via == .group })
        #expect(Set(candidates.filter { $0.via == .group }.map(\.userId)) == rosterIDs)
    }

    /// A conversation's roster never yields a candidate: its one other member is no one the caller shares a group with.
    @Test func aConversationIsNoSharedGroup() async throws {
        let groups = makeGroups()
        let repository = makeRepository(over: groups)
        _ = groups.startDirect(with: "mock-user-zed", name: "Zed")

        let candidates = try await repository.candidates(groupID: padel)

        #expect(!candidates.contains { $0.displayName == "Zed" || $0.viaName == "Marta" || $0.viaName == "Zed" })
        #expect(candidates.first { $0.userId == marta }?.viaName == "Kreuzberg Kickers")
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
        let lines = logger.messages(in: .groups, at: .info)
        #expect(lines.contains { $0.contains(sent.id) } && !lines.contains { $0.contains(sent.inviteeName) })
    }

    @Test func theBackendsRefusals() async {
        let repository = makeRepository()

        await #expect(throws: AppError.alreadyMember) {
            try await repository.invite(groupID: padel, userID: TestFixtures.user.id)
        }
        await #expect(throws: AppError.alreadyMember) {
            try await repository.invite(groupID: padel, userID: MockGroupFixtures.memberID(for: "Tom"))
        }
        await #expect(throws: AppError.cannotInvite) { try await repository.invite(groupID: padel, userID: priya) }
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
