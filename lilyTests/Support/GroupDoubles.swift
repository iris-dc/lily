import Foundation
@testable import lily

/// Scriptable `GroupRepository`: lists answer from `result`, writes from the stored groups, and every call is recorded.
/// `holdsRequests` parks the list, create and join requests; a single group read, the other writes, the roster and
/// the bans answer at once.
@MainActor
final class FakeGroupRepository: GroupRepository, HoldsRequests {
    var result: Result<[SportGroup], AppError> = .success([])
    /// The cursor the next list answer carries.
    var nextCursor: String?
    /// Thrown instead of `result` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    /// Thrown by every write when set.
    var actionError: (any Error)?
    /// Thrown by the next writes, one each, before `actionError` is consulted: a `.tryAgain` that a repeat gets past.
    var transientErrors: [AppError] = []
    /// Thrown by `bans(id:)` alone, so a roster that loaded while its banned list failed can be scripted.
    var bansError: (any Error)?
    var members: [GroupMember] = []
    let hold = RequestHold()
    private(set) var requestedScopes: [GroupScope] = []
    private(set) var requestedCursors: [String?] = []
    /// The position each list request carried (`nil` for none), in call order.
    private(set) var requestedPositions: [Coordinate?] = []
    private(set) var fetchedGroupIDs: [String] = []
    /// The group each roster read was for, in call order.
    private(set) var rosterRequests: [String] = []
    /// The group each banned-list read was for, in call order.
    private(set) var bansRequests: [String] = []
    private(set) var createdDrafts: [GroupDraft] = []
    private(set) var updatedDrafts: [(id: String, draft: GroupDraft)] = []
    private(set) var joinedGroupIDs: [String] = []
    private(set) var removals: [(id: String, userID: String)] = []
    private(set) var roleChanges: [RoleChange] = []

    struct RoleChange: Equatable {
        let id: String
        let userID: String
        let role: MemberRole
    }
    private(set) var unbans: [(id: String, userID: String)] = []

    func groups(in scope: GroupScope, cursor: String?, near position: Coordinate?) async throws -> Page<SportGroup> {
        requestedScopes.append(scope)
        requestedCursors.append(cursor)
        requestedPositions.append(position)
        try await hold.waitOrThrow()
        if let thrownError { throw thrownError }
        return Page(items: try result.get(), nextCursor: nextCursor)
    }

    func group(id: String) async throws -> SportGroup {
        fetchedGroupIDs.append(id)
        if let thrownError { throw thrownError }
        return try stored(id)
    }

    func create(_ draft: GroupDraft) async throws -> SportGroup {
        createdDrafts.append(draft)
        try await hold.waitOrThrow()
        try throwIfScripted()
        return draft.makeGroup(ownerName: TestFixtures.user.displayName, now: .now)
    }

    func update(id: String, _ draft: GroupDraft) async throws -> SportGroup {
        updatedDrafts.append((id, draft))
        try throwIfScripted()
        return try stored(id).updating(with: draft)
    }

    func delete(id: String) async throws -> SportGroup {
        try throwIfScripted()
        return try stored(id).markingDeleted(at: .now)
    }

    func join(id: String) async throws -> SportGroup {
        joinedGroupIDs.append(id)
        try await hold.waitOrThrow()
        try throwIfScripted()
        let group = try stored(id)
        return group.updatingMembership(GroupMembership(role: .member, joinedAt: .now), memberCount: group.memberCount + 1)
    }

    func leave(id: String) async throws -> SportGroup {
        try throwIfScripted()
        let group = try stored(id)
        return group.dropping()
    }

    func remove(id: String, userID: String) async throws -> SportGroup {
        removals.append((id, userID))
        try throwIfScripted()
        let group = try stored(id)
        return group.dropping(group.membership)
    }

    func setRole(id: String, userID: String, _ role: MemberRole) async throws -> GroupMember {
        roleChanges.append(RoleChange(id: id, userID: userID, role: role))
        try throwIfScripted()
        guard let member = members.first(where: { $0.userId == userID }) else { throw AppError.notAMember }
        return member.withRole(role)
    }

    func members(id: String) async throws -> [GroupMember] {
        rosterRequests.append(id)
        try throwIfScripted()
        return members.filter { $0.role != .banned }
    }

    func bans(id: String) async throws -> [GroupMember] {
        bansRequests.append(id)
        try throwIfScripted()
        if let bansError { throw bansError }
        return members.filter { $0.role == .banned }
    }

    func unban(id: String, userID: String) async throws {
        unbans.append((id, userID))
        try throwIfScripted()
    }

    private func throwIfScripted() throws {
        if !transientErrors.isEmpty { throw transientErrors.removeFirst() }
        if let actionError { throw actionError }
    }

    private func stored(_ id: String) throws -> SportGroup {
        guard let group = try result.get().first(where: { $0.id == id }) else { throw AppError.groupNotFound }
        return group
    }
}

/// Scriptable `InviteRepository`: candidates answer from `candidatesResult`, invites from `inviteResult` or, without
/// one, an invite built from the request; every call is recorded. `holdsRequests` parks every request until released.
@MainActor
final class FakeInviteRepository: InviteRepository, HoldsRequests {
    struct SentInviteRequest: Equatable {
        let groupID: String
        let userID: String
    }

    var candidatesResult: Result<[InviteCandidate], AppError> = .success([])
    /// Answered instead of an invite built from the request when set.
    var inviteResult: Result<SentInvite, AppError>?
    /// Thrown by the next invites, one each, before `inviteResult` is consulted: a `.tryAgain` that a repeat gets past.
    var transientInviteErrors: [AppError] = []
    let hold = RequestHold()
    private(set) var candidateRequests: [String] = []
    private(set) var sentInvites: [SentInviteRequest] = []

    func candidates(groupID: String) async throws -> [InviteCandidate] {
        candidateRequests.append(groupID)
        try await hold.waitOrThrow()
        return try candidatesResult.get()
    }

    func invite(groupID: String, userID: String) async throws -> SentInvite {
        sentInvites.append(SentInviteRequest(groupID: groupID, userID: userID))
        try await hold.waitOrThrow()
        if !transientInviteErrors.isEmpty { throw transientInviteErrors.removeFirst() }
        if let inviteResult { return try inviteResult.get() }
        return .fixture(groupID: groupID, inviteeUserId: userID)
    }
}

/// Scriptable `MeRepository`: `me()` answers from `meResult` (or throws `thrownError`), `acceptTerms` records the
/// version and refuses with `acceptError`; `holdsRequests` parks `me()` until `releaseRequests()`.
@MainActor
final class FakeMeRepository: MeRepository, HoldsRequests {
    var meResult: Result<Account, AppError> = .success(.fixture())
    /// Thrown by `me()` instead of `meResult` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    var acceptError: AppError?
    let hold = RequestHold()
    private(set) var meCallCount = 0
    private(set) var acceptedVersions: [Int] = []

    func me() async throws -> Account {
        meCallCount += 1
        try await hold.waitOrThrow()
        if let thrownError { throw thrownError }
        return try meResult.get()
    }

    func acceptTerms(version: Int) async throws -> TermsAcceptance {
        acceptedVersions.append(version)
        if let acceptError { throw acceptError }
        return TermsAcceptance(acceptedTermsVersion: version, acceptedTermsAt: .now)
    }
}

/// Scriptable `ModerationRepository`: every request is recorded, then refused with `error` when set;
/// `holdsRequests` parks every request until `releaseRequests()`.
@MainActor
final class FakeModerationRepository: ModerationRepository, HoldsRequests {
    var blocked: Set<String> = []
    /// Thrown by every request once it is recorded and, when held, released.
    var error: (any Error)?
    let hold = RequestHold()
    private(set) var reports: [ReportPayload] = []
    private(set) var blockedUserIDs: [String] = []
    private(set) var blocksRequestCount = 0

    func report(_ report: ReportPayload) async throws -> ReportReceipt {
        reports.append(report)
        try await answer()
        return ReportReceipt(id: "r-\(reports.count)", createdAt: .now)
    }

    func blocks() async throws -> Set<String> {
        blocksRequestCount += 1
        try await answer()
        return blocked
    }

    func block(userID: String) async throws -> Set<String> {
        blockedUserIDs.append(userID)
        try await answer()
        blocked.insert(userID)
        return blocked
    }

    func unblock(userID: String) async throws -> Set<String> {
        try await answer()
        blocked.remove(userID)
        return blocked
    }

    /// Every request's tail once recorded: the hold, then the scripted error.
    private func answer() async throws {
        try await hold.waitOrThrow()
        if let error { throw error }
    }
}
