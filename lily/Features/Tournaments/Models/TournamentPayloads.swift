import Foundation

/// Body of `POST /api/tournaments`: the backend's `CreateTournamentRequest` key for key. Blank optionals are omitted,
/// never sent as `null`; `visibility` is left out with a `groupId`, whose group's the tournament inherits.
nonisolated struct CreateTournamentPayload: Encodable, Equatable, Sendable {
    let clientTournamentId: String
    let name: String
    let description: String?
    let type: EventType
    let format: TournamentFormat
    let teamSize: Int
    let maxEntries: Int
    let allowsDraws: Bool
    let startsAt: Date
    let registrationClosesAt: Date?
    let location: CreateEventPayload.Location
    let groupId: String?
    let visibility: GroupVisibility?

    /// `nil` when the draft has no coordinate yet; callers validate the draft first.
    init?(draft: TournamentDraft) {
        guard let coordinate = draft.coordinate else { return nil }
        clientTournamentId = draft.clientId
        name = draft.trimmedName
        description = draft.trimmedDescription
        type = draft.type
        format = draft.format
        teamSize = draft.teamSize
        maxEntries = draft.maxEntries
        allowsDraws = draft.resolvedAllowsDraws
        startsAt = draft.startsAt
        registrationClosesAt = draft.registrationClosesAt
        location = CreateEventPayload.Location(name: draft.trimmedLocationName, coordinate: coordinate)
        groupId = draft.group?.id
        visibility = draft.group == nil ? draft.visibility : nil
    }
}

/// Body of `PUT /api/tournaments/{id}`: what the organiser may change. After the start only the name, the description
/// and the place may differ from what is stored; the rest is sent as it is.
nonisolated struct UpdateTournamentPayload: Encodable, Equatable, Sendable {
    let name: String
    let description: String?
    let startsAt: Date
    let registrationClosesAt: Date?
    let location: CreateEventPayload.Location
    let allowsDraws: Bool
    let maxEntries: Int

    /// `nil` when the draft has no coordinate; a draft made from a tournament always has one.
    init?(draft: TournamentDraft) {
        guard let coordinate = draft.coordinate else { return nil }
        name = draft.trimmedName
        description = draft.trimmedDescription
        startsAt = draft.startsAt
        registrationClosesAt = draft.registrationClosesAt
        location = CreateEventPayload.Location(name: draft.trimmedLocationName, coordinate: coordinate)
        allowsDraws = draft.resolvedAllowsDraws
        maxEntries = draft.maxEntries
    }
}

/// Body of `POST /api/tournaments/{id}/entries`: the team's name, required for a team tournament and omitted for an
/// individual entry, which is named after the player.
nonisolated struct CreateEntryPayload: Encodable, Equatable, Sendable {
    let name: String?
}

/// Body of `PUT .../matches/{matchId}/result`.
nonisolated struct MatchResultPayload: Encodable, Equatable, Sendable {
    let scoreA: Int
    let scoreB: Int
}

/// Body of `POST .../matches/{matchId}/walkover`.
nonisolated struct WalkoverPayload: Encodable, Equatable, Sendable {
    let winnerEntryId: String
}

/// Body of `PUT .../matches/{matchId}/schedule`; both fields absent clears the schedule.
nonisolated struct MatchSchedulePayload: Encodable, Equatable, Sendable {
    let scheduledAt: Date?
    let location: CreateEventPayload.Location?

    init(schedule: MatchSchedule) {
        scheduledAt = schedule.scheduledAt
        location = schedule.location.map { CreateEventPayload.Location(name: $0.name, coordinate: $0.coordinate) }
    }
}

/// What keeps a team's name from being sent, judged against `AppConfig.Tournaments.teamNameLength`.
nonisolated enum TeamNameIssue: Hashable, Sendable {
    case tooShort
    case tooLong

    static func issue(in name: String) -> TeamNameIssue? {
        let length = name.trimmingCharacters(in: .whitespacesAndNewlines).wireLength
        let limits = AppConfig.Tournaments.teamNameLength
        if length < limits.lowerBound { return .tooShort }
        if length > limits.upperBound { return .tooLong }
        return nil
    }
}
