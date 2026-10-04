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
        let page: Page<Tournament> = try await client.send(request, failingWith: .tournamentsUnavailable)
        return page.items
    }

    func tournament(id: String) async throws -> TournamentDetail {
        try await client.send(.get(AppConfig.API.Paths.tournament(id: id)), failingWith: .tournamentsUnavailable)
    }

    func create(_ draft: TournamentDraft) async throws -> TournamentDetail {
        guard let payload = CreateTournamentPayload(draft: draft) else { throw AppError.tournamentCreationFailed }
        let request = APIRequest<TournamentDetail>.post(AppConfig.API.Paths.tournaments, body: payload)
        return try await client.send(request, failingWith: .tournamentCreationFailed)
    }

    func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail {
        guard let payload = UpdateTournamentPayload(draft: draft) else { throw AppError.tournamentUpdateFailed }
        let request = APIRequest<TournamentDetail>.put(AppConfig.API.Paths.tournament(id: id), body: payload)
        return try await client.send(request, failingWith: .tournamentUpdateFailed)
    }

    func join(id: String, teamName: String?) async throws -> TournamentEntry {
        let request = APIRequest<TournamentEntry>.post(AppConfig.API.Paths.tournamentEntries(id: id),
                                                       body: CreateEntryPayload(name: teamName))
        return try await client.send(request, failingWith: .tournamentActionFailed)
    }

    func joinTeam(id: String, entryID: String) async throws -> TournamentEntry {
        let path = AppConfig.API.Paths.tournamentEntryMembers(id: id, entryID: entryID)
        return try await client.send(.post(path), failingWith: .tournamentActionFailed)
    }

    /// A `204` (the entry emptied) decodes as no entry.
    func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry? {
        let path = AppConfig.API.Paths.tournamentEntryMember(id: id, entryID: entryID, userID: userID)
        let answer: OptionalBody<TournamentEntry> = try await client.send(.delete(path), failingWith: .tournamentActionFailed)
        return answer.value
    }

    func removeEntry(id: String, entryID: String) async throws {
        let request = APIRequest<NoContent>.delete(AppConfig.API.Paths.tournamentEntry(id: id, entryID: entryID))
        _ = try await client.send(request, failingWith: .tournamentActionFailed)
    }

    func start(id: String) async throws -> TournamentDetail {
        try await client.send(.post(AppConfig.API.Paths.tournamentStart(id: id)), failingWith: .tournamentActionFailed)
    }

    func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail {
        let request = APIRequest<TournamentDetail>.put(AppConfig.API.Paths.matchResult(id: id, matchID: matchID),
                                                       body: MatchResultPayload(scoreA: scoreA, scoreB: scoreB))
        return try await client.send(request, failingWith: .tournamentActionFailed)
    }

    func confirm(id: String, matchID: String) async throws -> TournamentDetail {
        let path = AppConfig.API.Paths.matchConfirm(id: id, matchID: matchID)
        return try await client.send(.post(path), failingWith: .tournamentActionFailed)
    }

    func dispute(id: String, matchID: String) async throws -> TournamentDetail {
        let path = AppConfig.API.Paths.matchDispute(id: id, matchID: matchID)
        return try await client.send(.post(path), failingWith: .tournamentActionFailed)
    }

    func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail {
        let request = APIRequest<TournamentDetail>.post(AppConfig.API.Paths.matchWalkover(id: id, matchID: matchID),
                                                        body: WalkoverPayload(winnerEntryId: winnerEntryID))
        return try await client.send(request, failingWith: .tournamentActionFailed)
    }

    func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch {
        let request = APIRequest<TournamentMatch>.put(AppConfig.API.Paths.matchSchedule(id: id, matchID: matchID),
                                                      body: MatchSchedulePayload(schedule: schedule))
        return try await client.send(request, failingWith: .tournamentActionFailed)
    }

    func cancel(id: String) async throws -> TournamentDetail {
        try await client.send(.post(AppConfig.API.Paths.tournamentCancel(id: id)), failingWith: .tournamentActionFailed)
    }
}

private extension RemoteTournamentRepository {
    /// A group's tournaments have a resource of their own; the other scopes are a query on `/api/tournaments`, with the
    /// position only on Explore, where the backend records it for the statistics.
    static func listRequest(for scope: TournamentScope, near position: Coordinate?) -> APIRequest<Page<Tournament>> {
        let scopeKey = AppConfig.API.Query.scope
        switch scope {
        case .group(let id):
            return .get(AppConfig.API.Paths.groupTournaments(id: id))
        case .upcoming:
            let query = [URLQueryItem(name: scopeKey, value: "upcoming")] + (position?.queryItems ?? [])
            return .get(AppConfig.API.Paths.tournaments, query: query)
        case .mine:
            return .get(AppConfig.API.Paths.tournaments, query: [URLQueryItem(name: scopeKey, value: "mine")])
        }
    }
}
