import Foundation

/// Profiles from the group mock's rosters, for previews, UI tests and `-mock-events` runs: a person is whoever any
/// roster names, and the groups in common are the caller's communities whose roster names them (a conversation with
/// the person is no group in common). Conversations are the group mock's direct groups.
final class MockUserRepository: UserRepository {
    private let groups: MockGroupRepository
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(groups: MockGroupRepository, identity: any IdentityProvider, logger: any Logging) {
        self.groups = groups
        self.identity = identity
        self.logger = logger
    }

    /// The caller's own id answers their own groups, as the backend does.
    func profile(userID: String) async throws -> UserProfile {
        guard let caller = identity.currentUserID else { throw AppError.sessionExpired }
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items
            .filter(\.isCommunity)
        if userID == caller {
            return UserProfile(userId: caller,
                               displayName: AppBranding.Groups.Create.mockOwnerName,
                               sharedGroups: summaries(mine))
        }
        guard let name = groups.displayName(ofUser: userID) else { throw AppError.userNotFound }
        let shared = mine.filter { group in
            groups.roster(of: group.id).contains { $0.userId == userID && $0.role != .banned }
        }
        logger.debug(.groups, "Mock profile \(userID) served with \(shared.count) shared groups")
        return UserProfile(userId: userID, displayName: name, sharedGroups: summaries(shared))
    }

    func startConversation(with userID: String) async throws -> SportGroup {
        guard let caller = identity.currentUserID else { throw AppError.sessionExpired }
        guard userID != caller else { throw AppError.conversationFailed }
        guard let name = groups.displayName(ofUser: userID) else { throw AppError.userNotFound }
        return groups.startDirect(with: userID, name: name)
    }

    /// Sorted by name, as the backend answers them.
    private func summaries(_ shared: [SportGroup]) -> [GroupSummary] {
        shared.sorted { $0.name < $1.name }.map(GroupSummary.init)
    }
}
