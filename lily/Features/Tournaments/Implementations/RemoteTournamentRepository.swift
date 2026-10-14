import Foundation

/// Tournaments from the Laurel backend. Failures arrive as `AppError`, ready for the popup.
final class RemoteTournamentRepository: TournamentRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    /// Every list comes as `{items: [Tournament]}` without a cursor.
    func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament] {
        let request = Self.listRequest(for: scope, near: position)
        let page: Page<Tournament> = try await send(request, failingWith: .tournamentsUnavailable)
        return page.items
    }

    func tournament(id: String) async throws -> TournamentDetail {
        try await send(.get(AppConfig.API.Paths.tournament(id: id)), failingWith: .tournamentsUnavailable)
    }

    func create(_ draft: TournamentDraft) async throws -> TournamentDetail {
        guard let payload = CreateTournamentPayload(draft: draft) else { throw AppError.tournamentCreationFailed }
        let request = APIRequest<TournamentDetail>.post(AppConfig.API.Paths.tournaments, body: payload)
        return try await send(request, failingWith: .tournamentCreationFailed)
    }

    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail {
        guard let payload = UpdateTournamentPayload(draft: draft) else { throw AppError.tournamentUpdateFailed }
        let request = APIRequest<TournamentDetail>.put(AppConfig.API.Paths.tournament(id: id), body: payload)
        return try await send(request, failingWith: .tournamentUpdateFailed)
    }

    func join(id: String, teamName: String?) async throws -> TournamentEntry {
        let request = APIRequest<TournamentEntry>.post(AppConfig.API.Paths.tournamentEntries(id: id),
                                                       body: CreateEntryPayload(name: teamName))
        return try await send(request, failingWith: .tournamentActionFailed)
    }

    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry {
        let path = AppConfig.API.Paths.tournamentEntryMembers(id: id, entryID: entryID)
        return try await send(.post(path), failingWith: .tournamentActionFailed)
    }

    /// A `204` (the entry emptied) decodes as no entry.
    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry? {
        let path = AppConfig.API.Paths.tournamentEntryMember(id: id, entryID: entryID, userID: userID)
        let answer: OptionalBody<TournamentEntry> = try await send(.delete(path), failingWith: .tournamentActionFailed)
        return answer.value
    }

    func removeEntry(id: String, entryID: String) async throws {
        let request = APIRequest<NoContent>.delete(AppConfig.API.Paths.tournamentEntry(id: id, entryID: entryID))
        _ = try await send(request, failingWith: .tournamentActionFailed)
    }

    func start(id: String) async throws -> TournamentDetail {
        try await send(.post(AppConfig.API.Paths.tournamentStart(id: id)), failingWith: .tournamentActionFailed)
    }

    func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail {
        let request = APIRequest<TournamentDetail>.put(AppConfig.API.Paths.matchResult(id: id, matchID: matchID),
                                                       body: MatchResultPayload(scoreA: scoreA, scoreB: scoreB))
        return try await send(request, failingWith: .tournamentActionFailed)
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        let path = AppConfig.API.Paths.matchConfirm(id: id, matchID: matchID)
        return try await send(.post(path), failingWith: .tournamentActionFailed)
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        let path = AppConfig.API.Paths.matchDispute(id: id, matchID: matchID)
        return try await send(.post(path), failingWith: .tournamentActionFailed)
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        let request = APIRequest<TournamentDetail>.post(AppConfig.API.Paths.matchWalkover(id: id, matchID: matchID),
                                                        body: WalkoverPayload(winnerEntryId: winnerEntryID))
        return try await send(request, failingWith: .tournamentActionFailed)
    }

    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        let request = APIRequest<TournamentMatch>.put(AppConfig.API.Paths.matchSchedule(id: id, matchID: matchID),
                                                      body: MatchSchedulePayload(schedule: schedule))
        return try await send(request, failingWith: .tournamentActionFailed)
    }

    func cancel(id: String) async throws -> TournamentDetail {
        try await send(.post(AppConfig.API.Paths.tournamentCancel(id: id)), failingWith: .tournamentActionFailed)
    }
}

private extension RemoteTournamentRepository {
    /// The shared mapping reads `MEMBERSHIP_LIMIT` as the groups cap; on a tournament route it is the cap on the
    /// tournaments one may be in.
    func send<Response: Decodable>(_ request: APIRequest<Response>, failingWith fallback: AppError) async throws -> Response {
        do {
            return try await client.send(request, failingWith: fallback)
        } catch AppError.membershipLimitReached {
            throw AppError.tournamentMembershipLimit
        }
    }

    /// A group's tournaments have a resource of their own; the other scopes are a query on `/api/tournaments`, with the
    /// position only on Explore, where the backend records it for the statistics.
    static func listRequest(for scope: TournamentScope, near position: Coordinate?) -> APIRequest<Page<Tournament>> {
        switch scope {
        case .group(let id):
            .get(AppConfig.API.Paths.groupTournaments(id: id))
        case .upcoming:
            .get(AppConfig.API.Paths.tournaments, query: scopeItems(for: scope) + (position?.queryItems ?? []))
        case .mine:
            .get(AppConfig.API.Paths.tournaments, query: scopeItems(for: scope))
        }
    }

    /// The `scope` item, or none for a scope that is a resource of its own.
    private static func scopeItems(for scope: TournamentScope) -> [URLQueryItem] {
        guard let name = scope.wireName else { return [] }
        return [URLQueryItem(name: AppConfig.API.Query.scope, value: name)]
    }
}
