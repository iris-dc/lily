import Foundation

/// Profiles from the other mocks' rosters, for previews, UI tests and `-mock-events` runs: a person is whoever any
/// roster names, their bio a fixture line (the caller's own is the profile mock's), the groups in common the caller's
/// communities whose roster names them (a conversation with the person is no group in common), the games together the
/// caller's joined games whose participants name them, and the tournaments together the ones whose room both are in.
/// Conversations are the group mock's direct groups.
final class MockUserRepository: UserRepository {
    private let groups: MockGroupRepository
    private let events: MockEventRepository
    private let tournaments: MockTournamentRepository
    private let profiles: MockProfileRepository
    private let identity: any IdentityProvider
    private let logger: any Logging

    init(groups: MockGroupRepository,
         events: MockEventRepository,
         tournaments: MockTournamentRepository,
         profiles: MockProfileRepository,
         identity: any IdentityProvider,
         logger: any Logging) {
        self.groups = groups
        self.events = events
        self.tournaments = tournaments
        self.profiles = profiles
        self.identity = identity
        self.logger = logger
    }

    /// The caller's own id answers their own groups, games and tournaments, as the backend does.
    func profile(userID: String) async throws -> UserProfile {
        guard let caller = identity.currentUserID else { throw AppError.sessionExpired }
        let isSelf = userID == caller
        guard let name = isSelf ? AppBranding.Groups.Create.mockOwnerName : groups.displayName(ofUser: userID) else {
            throw AppError.userNotFound
        }
        let mine = try await groups.groups(in: .mine, cursor: nil, near: nil).items.filter(\.isCommunity)
        let shared = isSelf ? mine : mine.filter { group in
            groups.roster(of: group.id).contains { $0.userId == userID && $0.role != .banned }
        }
        let bio = try await bio(of: userID, isSelf: isSelf)
        let sharedEvents = try await sharedEvents(with: userID, isSelf: isSelf)
        let profile = UserProfile(userId: userID,
                                  displayName: name,
                                  bio: bio,
                                  sharedGroups: summaries(shared),
                                  sharedEvents: sharedEvents,
                                  sharedTournaments: sharedTournaments(with: userID, isSelf: isSelf))
        logger.debug(.groups, "Mock profile \(userID) served with \(shared.count) shared groups, "
            + "\(profile.sharedEvents.count) games and \(profile.sharedTournaments.count) tournaments")
        return profile
    }

    func startConversation(with userID: String) async throws -> SportGroup {
        guard let caller = identity.currentUserID else { throw AppError.sessionExpired }
        guard userID != caller else { throw AppError.conversationFailed }
        guard let name = groups.displayName(ofUser: userID) else { throw AppError.userNotFound }
        return groups.startDirect(with: userID, name: name)
    }

    private func bio(of userID: String, isSelf: Bool) async throws -> String? {
        if isSelf { return try await profiles.profile().bio }
        return MockUserFixtures.bio(of: userID)
    }

    /// Sorted by name, as the backend answers them.
    private func summaries(_ shared: [SportGroup]) -> [GroupSummary] {
        shared.sorted { $0.name < $1.name }.map(GroupSummary.init)
    }

    /// The caller's joined games the person is in too (the host included), the latest first, as many as Laurel lists.
    private func sharedEvents(with userID: String, isSelf: Bool) async throws -> [EventSummary] {
        var shared: [EventSummary] = []
        for event in try await events.events(in: .joined, near: nil) {
            if !isSelf {
                let participants = try await events.participants(eventId: event.id)
                guard participants.contains(where: { $0.userId == userID }) else { continue }
            }
            shared.append(EventSummary(event))
        }
        return latestFirst(shared, by: \.startsAt)
    }

    /// The tournaments whose room both are in: the caller plays or organises, and so does the person; a cancelled one was
    /// never played.
    private func sharedTournaments(with userID: String, isSelf: Bool) -> [TournamentSummary] {
        let shared = tournaments.details.values
            .filter { tournaments.isInRoom($0.tournament) && (isSelf || involves($0, userID)) }
            .map { tournaments.resolved($0.tournament) }
            .filter { $0.status != .cancelled }
            .map(TournamentSummary.init)
        return latestFirst(shared, by: \.startsAt)
    }

    private func involves(_ detail: TournamentDetail, _ userID: String) -> Bool {
        detail.tournament.isOrganized(by: userID) || detail.entry(containing: userID) != nil
    }

    private func latestFirst<Item>(_ items: [Item], by startsAt: KeyPath<Item, Date>) -> [Item] {
        Array(items.sorted { $0[keyPath: startsAt] > $1[keyPath: startsAt] }.prefix(AppConfig.People.maxSharedHistory))
    }
}
