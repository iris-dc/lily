import Foundation
import Testing
@testable import lily

@MainActor
struct MockInviteRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    private let logger = SpyLogger()
    private let mockCode = InviteCode(AppConfig.Groups.mockInviteCode)!

    private func makeRepositories() -> (groups: MockGroupRepository, invites: MockInviteRepository) {
        let groups = MockGroupRepository(identity: identity, logger: logger)
        return (groups, MockInviteRepository(groups: groups, identity: identity, logger: logger))
    }

    /// The fixed code previews and opens Climbing Buddies, the private group nothing else reaches.
    @Test func theMockCodeOpensClimbingBuddies() async throws {
        let (groups, invites) = makeRepositories()

        let preview = try await invites.preview(code: mockCode)
        #expect(preview.group.name == "Climbing Buddies" && preview.group.visibility == .private && !preview.isMember)

        let joined = try await invites.redeem(code: mockCode)
        #expect(joined.id == MockGroupFixtures.climbingID && joined.role == .member && joined.memberCount == 10)
        #expect(try await groups.group(id: MockGroupFixtures.climbingID).isMember)
        #expect(try await invites.preview(code: mockCode).isMember)
        #expect(logger.messages(in: .groups, at: .info).contains("Invite redeemed for group \(MockGroupFixtures.climbingID)"))
    }

    @Test func guestsPreviewButAreNeverMembers() async throws {
        identity.currentUserID = nil
        let (_, invites) = makeRepositories()

        #expect(try await invites.preview(code: mockCode).isMember == false)
    }

    @Test func unknownCodesAreInvalid() async {
        let (_, invites) = makeRepositories()
        let unknown = InviteCode("0123456789AB")!

        await #expect(throws: AppError.inviteInvalid) { try await invites.preview(code: unknown) }
        await #expect(throws: AppError.inviteInvalid) { try await invites.redeem(code: unknown) }
    }

    @Test func createdInvitesWorkUntilRevoked() async throws {
        let (_, invites) = makeRepositories()

        let options = InviteOptions(maxUses: 1, expiresInDays: 1)
        let invite = try await invites.create(groupID: MockGroupFixtures.padelID, options: options)
        let code = try #require(invite.code.flatMap(InviteCode.init))
        #expect(invite.url == AppConfig.Groups.inviteLinkBaseURL.appending(path: code.value))
        #expect(invite.groupId == MockGroupFixtures.padelID && invite.maxUses == 1 && invite.createdBy == TestFixtures.user.id)
        #expect(try await invites.list(groupID: MockGroupFixtures.padelID) == [invite])
        #expect(try await invites.preview(code: code).group.name == "Sunday Padel Crew")

        let revoked = try await invites.revoke(groupID: MockGroupFixtures.padelID, inviteID: invite.inviteId)
        #expect(revoked.isRevoked && revoked.inviteId == invite.inviteId)
        #expect(try await invites.list(groupID: MockGroupFixtures.padelID).isEmpty)
        await #expect(throws: AppError.inviteInvalid) { try await invites.preview(code: code) }
        await #expect(throws: AppError.inviteInvalid) {
            try await invites.revoke(groupID: MockGroupFixtures.padelID, inviteID: "x")
        }
    }

    /// Members invite only where the group allows it; an outsider cannot invite at all.
    @Test func invitingFollowsGroupAccess() async {
        let (_, invites) = makeRepositories()

        await #expect(throws: AppError.insufficientRole) {
            try await invites.create(groupID: MockGroupFixtures.basketballID, options: InviteOptions())
        }
    }
}

@MainActor
struct MockMeAndModerationRepositoryTests {
    private let identity = FakeIdentityProvider(currentUserID: MockUsers.user(for: .apple).id)
    private let logger = SpyLogger()

    @Test func theAppleTesterIsAnOperatorWithTheTermsAccepted() async throws {
        let repository = MockMeRepository(identity: identity, logger: logger)

        let account = try await repository.me()
        #expect(account.userId == identity.currentUserID && account.isOperator && account.termsAccepted)
        #expect(account.realtimeEndpoint == nil)

        identity.currentUserID = "mock-google"
        #expect(try await repository.me().isOperator == false)

        identity.currentUserID = nil
        await #expect(throws: AppError.sessionExpired) { try await repository.me() }
    }

    @Test func termsAcceptanceEchoesTheVersion() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = MockMeRepository(identity: identity, logger: logger) { now }

        #expect(try await repository.acceptTerms(version: 3) == TermsAcceptance(acceptedTermsVersion: 3, acceptedTermsAt: now))
    }

    @Test func blocksAreKeptAndCapped() async throws {
        let repository = MockModerationRepository(logger: logger)

        #expect(try await repository.blocks().isEmpty)
        #expect(try await repository.block(userID: "u-2") == ["u-2"])
        #expect(try await repository.block(userID: "u-2") == ["u-2"])
        #expect(try await repository.unblock(userID: "u-2").isEmpty)

        for index in 0..<AppConfig.Moderation.maxBlocks {
            _ = try await repository.block(userID: "u-\(index)")
        }
        await #expect(throws: AppError.blockLimitReached) { try await repository.block(userID: "one-too-many") }
        #expect(try await repository.block(userID: "u-1").count == AppConfig.Moderation.maxBlocks, "an existing block is fine")
    }

    @Test func reportsAreAcceptedAndLoggedWithoutText() async throws {
        let repository = MockModerationRepository(logger: logger)

        let report = ReportPayload(target: .message(id: "m1", groupID: "g1"), reason: .spam, comment: "secret")
        let receipt = try await repository.report(report)

        #expect(!receipt.id.isEmpty)
        #expect(logger.messages(in: .groups, at: .info) == ["Mock report filed on message m1"])
    }
}
