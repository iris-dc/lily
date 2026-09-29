import Foundation
@testable import lily

/// Scriptable `GroupRepository`: lists answer from `result`, writes from the stored groups, and every call is recorded.
@MainActor
final class FakeGroupRepository: GroupRepository {
    var result: Result<[SportGroup], AppError> = .success([])
    /// The cursor the next list answer carries.
    var nextCursor: String?
    /// Thrown instead of `result` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    /// Thrown by every write when set.
    var actionError: (any Error)?
    /// Thrown by the next writes, one each, before `actionError` is consulted: a `.tryAgain` that a repeat gets past.
    var transientErrors: [AppError] = []
    /// While true, list and write requests record the call and then suspend until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    var members: [GroupMember] = []
    private let hold = RequestHold()
    private(set) var requestedScopes: [GroupScope] = []
    private(set) var requestedCursors: [String?] = []
    private(set) var fetchedGroupIDs: [String] = []
    private(set) var createdDrafts: [GroupDraft] = []
    private(set) var updatedDrafts: [(id: String, draft: GroupDraft)] = []
    private(set) var deletedGroupIDs: [String] = []
    private(set) var joinedGroupIDs: [String] = []
    private(set) var leftGroupIDs: [String] = []
    private(set) var removals: [(id: String, userID: String)] = []
    private(set) var roleChanges: [RoleChange] = []

    struct RoleChange: Equatable {
        let id: String
        let userID: String
        let role: MemberRole
    }
    private(set) var unbans: [(id: String, userID: String)] = []

    func groups(in scope: GroupScope, cursor: String?) async throws -> Page<SportGroup> {
        requestedScopes.append(scope)
        requestedCursors.append(cursor)
        try await holdIfRequested()
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
        try await holdIfRequested()
        try throwIfScripted()
        return draft.makeGroup(ownerName: TestFixtures.user.displayName, now: .now)
    }

    func update(id: String, _ draft: GroupDraft) async throws -> SportGroup {
        updatedDrafts.append((id, draft))
        try throwIfScripted()
        return try stored(id).updating(with: draft)
    }

    func delete(id: String) async throws -> SportGroup {
        deletedGroupIDs.append(id)
        try throwIfScripted()
        return try stored(id).markingDeleted(at: .now)
    }

    func join(id: String) async throws -> SportGroup {
        joinedGroupIDs.append(id)
        try await holdIfRequested()
        try throwIfScripted()
        let group = try stored(id)
        return group.updatingMembership(GroupMembership(role: .member, joinedAt: .now), memberCount: group.memberCount + 1)
    }

    func leave(id: String) async throws -> SportGroup {
        leftGroupIDs.append(id)
        try throwIfScripted()
        let group = try stored(id)
        return group.updatingMembership(nil, memberCount: group.memberCount - 1, channelEpoch: group.channelEpoch + 1)
    }

    func remove(id: String, userID: String) async throws -> SportGroup {
        removals.append((id, userID))
        try throwIfScripted()
        let group = try stored(id)
        return group.updatingMembership(group.membership,
                                        memberCount: group.memberCount - 1,
                                        channelEpoch: group.channelEpoch + 1)
    }

    func setRole(id: String, userID: String, _ role: MemberRole) async throws -> GroupMember {
        roleChanges.append(RoleChange(id: id, userID: userID, role: role))
        try throwIfScripted()
        guard let member = members.first(where: { $0.userId == userID }) else { throw AppError.notAMember }
        return member.withRole(role)
    }

    func members(id: String) async throws -> [GroupMember] {
        try throwIfScripted()
        return members.filter { $0.role != .banned }
    }

    func bans(id: String) async throws -> [GroupMember] {
        try throwIfScripted()
        return members.filter { $0.role == .banned }
    }

    func unban(id: String, userID: String) async throws {
        unbans.append((id, userID))
        try throwIfScripted()
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    /// A caller cancelled while held learns of it once the hold lifts, as a URLSession task does.
    private func holdIfRequested() async throws {
        await hold.wait()
        try Task.checkCancellation()
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
final class FakeInviteRepository: InviteRepository {
    struct SentInviteRequest: Equatable {
        let groupID: String
        let userID: String
    }

    var candidatesResult: Result<[InviteCandidate], AppError> = .success([])
    /// Answered instead of an invite built from the request when set.
    var inviteResult: Result<SentInvite, AppError>?
    /// Thrown by the next invites, one each, before `inviteResult` is consulted: a `.tryAgain` that a repeat gets past.
    var transientInviteErrors: [AppError] = []
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    private let hold = RequestHold()
    private(set) var candidateRequests: [String] = []
    private(set) var sentInvites: [SentInviteRequest] = []

    func candidates(groupID: String) async throws -> [InviteCandidate] {
        candidateRequests.append(groupID)
        try await holdIfRequested()
        return try candidatesResult.get()
    }

    func invite(groupID: String, userID: String) async throws -> SentInvite {
        sentInvites.append(SentInviteRequest(groupID: groupID, userID: userID))
        try await holdIfRequested()
        if !transientInviteErrors.isEmpty { throw transientInviteErrors.removeFirst() }
        if let inviteResult { return try inviteResult.get() }
        return .fixture(groupID: groupID, inviteeUserId: userID)
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    /// A caller cancelled while held learns of it once the hold lifts, as a URLSession task does.
    private func holdIfRequested() async throws {
        await hold.wait()
        try Task.checkCancellation()
    }
}

@MainActor
final class FakeMeRepository: MeRepository {
    var meResult: Result<Account, AppError> = .success(.fixture())
    /// Thrown by `me()` instead of `meResult` when set, for errors that are not `AppError` (such as `CancellationError`).
    var thrownError: (any Error)?
    var acceptError: AppError?
    /// While true, `me()` records the call and then suspends until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    private let hold = RequestHold()
    private(set) var meCallCount = 0
    private(set) var acceptedVersions: [Int] = []

    /// A caller cancelled while held learns of it once the hold lifts, as a URLSession task does.
    func me() async throws -> Account {
        meCallCount += 1
        await hold.wait()
        try Task.checkCancellation()
        if let thrownError { throw thrownError }
        return try meResult.get()
    }

    /// Lets every held request through and stops holding new ones.
    func releaseRequests() {
        hold.release()
    }

    func acceptTerms(version: Int) async throws -> TermsAcceptance {
        acceptedVersions.append(version)
        if let acceptError { throw acceptError }
        return TermsAcceptance(acceptedTermsVersion: version, acceptedTermsAt: .now)
    }
}

@MainActor
final class FakeModerationRepository: ModerationRepository {
    var blocked: Set<String> = []
    var error: AppError?
    private(set) var reports: [ReportPayload] = []
    private(set) var blockedUserIDs: [String] = []
    private(set) var unblockedUserIDs: [String] = []

    func report(_ report: ReportPayload) async throws -> ReportReceipt {
        reports.append(report)
        if let error { throw error }
        return ReportReceipt(id: "r-\(reports.count)", createdAt: .now)
    }

    func blocks() async throws -> Set<String> {
        if let error { throw error }
        return blocked
    }

    func block(userID: String) async throws -> Set<String> {
        blockedUserIDs.append(userID)
        if let error { throw error }
        blocked.insert(userID)
        return blocked
    }

    func unblock(userID: String) async throws -> Set<String> {
        unblockedUserIDs.append(userID)
        if let error { throw error }
        blocked.remove(userID)
        return blocked
    }
}
