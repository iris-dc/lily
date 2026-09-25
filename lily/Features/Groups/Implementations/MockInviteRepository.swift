import Foundation

/// Invites without a backend: the one fixed code opens Climbing Buddies, and codes created here work until revoked.
final class MockInviteRepository: InviteRepository {
    private var invites: [Invite] = []
    private let groups: MockGroupRepository
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let now: () -> Date

    init(groups: MockGroupRepository, identity: any IdentityProvider, logger: any Logging, now: @escaping () -> Date = { .now }) {
        self.groups = groups
        self.identity = identity
        self.logger = logger
        self.now = now
    }

    func create(groupID: String, options: InviteOptions) async throws -> Invite {
        let group = try await groups.group(id: groupID)
        guard GroupAccess(group: group, userID: identity.currentUserID).canInvite(in: group) else {
            throw AppError.insufficientRole
        }
        let code = Self.randomCode()
        let created = now()
        let invite = Invite(inviteId: UUID().uuidString.lowercased(),
                            code: code,
                            url: AppConfig.Groups.inviteLinkBaseURL.appending(path: code),
                            groupId: groupID,
                            createdBy: identity.currentUserID ?? "",
                            createdAt: created,
                            expiresAt: created.addingTimeInterval(TimeInterval(options.expiresInDays) * Self.secondsPerDay),
                            maxUses: options.maxUses,
                            uses: 0,
                            revokedAt: nil)
        invites.append(invite)
        logger.info(.groups, "Invite \(invite.inviteId) created for group \(groupID)")
        return invite
    }

    func list(groupID: String) async throws -> [Invite] {
        invites.filter { $0.groupId == groupID && !$0.isRevoked }
    }

    func revoke(groupID: String, inviteID: String) async throws -> Invite {
        guard let index = invites.firstIndex(where: { $0.groupId == groupID && $0.inviteId == inviteID }) else {
            throw AppError.inviteInvalid
        }
        if !invites[index].isRevoked {
            invites[index] = invites[index].revoked(at: now())
        }
        return invites[index]
    }

    func preview(code: InviteCode) async throws -> InvitePreview {
        let (groupID, expiresAt) = try target(of: code)
        let group = try groups.peek(id: groupID)
        return InvitePreview(group: InvitePreview.GroupSummary(id: group.id,
                                                               name: group.name,
                                                               description: group.description,
                                                               visibility: group.visibility,
                                                               type: group.type,
                                                               memberCount: group.memberCount),
                             expiresAt: expiresAt,
                             isMember: identity.currentUserID != nil && group.isMember)
    }

    func redeem(code: InviteCode) async throws -> SportGroup {
        let (groupID, _) = try target(of: code)
        let group = try groups.admit(id: groupID)
        logger.info(.groups, "Invite redeemed for group \(groupID)")
        return group
    }

    /// The group behind a code and when the code expires; the fixed mock code never does.
    private func target(of code: InviteCode) throws -> (groupID: String, expiresAt: Date) {
        if code.value == AppConfig.Groups.mockInviteCode {
            return (MockGroupFixtures.climbingID, now().addingTimeInterval(Self.mockCodeLifetime))
        }
        guard let invite = invites.first(where: { $0.code == code.value }), !invite.isRevoked else {
            throw AppError.inviteInvalid
        }
        guard invite.expiresAt > now() else { throw AppError.inviteExpired }
        return (invite.groupId, invite.expiresAt)
    }

    private static let secondsPerDay = 86_400.0
    private static let mockCodeLifetime = TimeInterval(AppConfig.Groups.inviteDefaultDays) * secondsPerDay

    private static func randomCode() -> String {
        String((0..<AppConfig.Groups.inviteCodeLength).compactMap { _ in AppConfig.Groups.inviteCodeAlphabet.randomElement() })
    }
}
