import Foundation

/// Decodes the backend's `Tournament` directly: same keys, same optionality. The place and the group ref are the
/// event's types, as the backend reuses its `LocationDto` and `GroupRefDto`. The mutating copies are what the mock
/// repository answers; the backend builds the same shapes.
nonisolated struct Tournament: Identifiable, Hashable, Codable, Sendable {
    let id: String
    private(set) var name: String
    private(set) var description: String?
    let type: EventType
    let format: TournamentFormat
    private(set) var status: TournamentStatus
    /// A group-hosted tournament inherits its group's; a standalone one picks its own.
    let visibility: GroupVisibility
    /// One means players enter alone; more means a captain names a team and teammates join it.
    let teamSize: Int
    private(set) var maxEntries: Int
    private(set) var entryCount: Int
    private(set) var allowsDraws: Bool
    private(set) var startsAt: Date
    /// Entries close here when set, at the start otherwise.
    private(set) var registrationClosesAt: Date?
    private(set) var location: EventLocation
    let organizerUserId: String
    let organizerName: String
    let group: EventGroupRef?
    /// The room's epoch; the chat channel is `rooms/<id>/<channelEpoch>`.
    private(set) var channelEpoch: Int
    /// The caller's entry, for a signed-in caller who has one.
    private(set) var myEntryId: String?
    private(set) var winnerEntryId: String?
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?
    let createdAt: Date
    private(set) var updatedAt: Date?

    init(id: String,
         name: String,
         description: String? = nil,
         type: EventType,
         format: TournamentFormat,
         status: TournamentStatus = .registration,
         visibility: GroupVisibility = .public,
         teamSize: Int = 1,
         maxEntries: Int,
         entryCount: Int = 0,
         allowsDraws: Bool = false,
         startsAt: Date,
         registrationClosesAt: Date? = nil,
         location: EventLocation,
         organizerUserId: String,
         organizerName: String,
         group: EventGroupRef? = nil,
         channelEpoch: Int = 1,
         myEntryId: String? = nil,
         winnerEntryId: String? = nil,
         startedAt: Date? = nil,
         completedAt: Date? = nil,
         createdAt: Date,
         updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.format = format
        self.status = status
        self.visibility = visibility
        self.teamSize = teamSize
        self.maxEntries = maxEntries
        self.entryCount = entryCount
        self.allowsDraws = allowsDraws
        self.startsAt = startsAt
        self.registrationClosesAt = registrationClosesAt
        self.location = location
        self.organizerUserId = organizerUserId
        self.organizerName = organizerName
        self.group = group
        self.channelEpoch = channelEpoch
        self.myEntryId = myEntryId
        self.winnerEntryId = winnerEntryId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isTeam: Bool { teamSize > 1 }
    var isPublic: Bool { visibility == .public }
    var hasEntered: Bool { myEntryId != nil }
    var isFull: Bool { entryCount >= maxEntries }
    var locationName: String { location.name }
    /// Explore lists public tournaments in registration; a private one is found on Home and under its group.
    var isListed: Bool { isPublic && status == .registration }
    var fillRatio: Double { min(1, Double(entryCount) / Double(max(maxEntries, 1))) }
    var canStart: Bool { status == .registration && entryCount >= format.minimumEntriesToStart }
    /// Whether a match may end level: a knockout match always needs a winner, whatever `allowsDraws` says (the backend
    /// refuses a draw there); a round robin follows the setting.
    var permitsDraws: Bool { allowsDraws && format == .roundRobin }
    /// "3 of 8 teams" or "6 of 12 players".
    var entriesText: String { AppBranding.Tournaments.entries(entryCount, of: maxEntries, teamSize: teamSize) }
    /// For log lines: the shape of the field, never a name.
    var entriesDescription: String {
        isTeam ? "\(entryCount) of \(maxEntries) teams of \(teamSize)" : "\(entryCount) of \(maxEntries) players"
    }
    var destination: TournamentDestination { TournamentDestination(id: id, name: name) }

    func isOrganized(by userID: String?) -> Bool {
        userID != nil && organizerUserId == userID
    }

    /// Entries are taken while in registration and, with a deadline, before it.
    func isRegistrationOpen(now: Date) -> Bool {
        status == .registration && (registrationClosesAt.map { now < $0 } ?? true)
    }

    /// Meters from `origin`, or `nil` when the user's position is unknown.
    func distance(from origin: Coordinate?) -> Measurement<UnitLength>? {
        origin.map { Measurement(value: location.coordinate.distance(to: $0), unit: .meters) }
    }

    /// After an entry joined or left: the count and the caller's own entry as the backend now sees them.
    func updatingEntries(count: Int, myEntryId: String?, channelEpoch: Int? = nil, at date: Date) -> Tournament {
        var copy = self
        copy.entryCount = count
        copy.myEntryId = myEntryId
        copy.channelEpoch = channelEpoch ?? self.channelEpoch
        copy.updatedAt = date
        return copy
    }

    /// The organiser's edit: every field the draft may change; the backend keeps the rest.
    func updating(with draft: TournamentDraft, at date: Date) -> Tournament {
        var copy = self
        copy.name = draft.trimmedName
        copy.description = draft.trimmedDescription
        copy.startsAt = draft.startsAt
        copy.registrationClosesAt = draft.registrationClosesAt
        copy.location = EventLocation(name: draft.trimmedLocationName, coordinate: draft.coordinate ?? location.coordinate)
        copy.allowsDraws = draft.resolvedAllowsDraws
        copy.maxEntries = draft.maxEntries
        copy.updatedAt = date
        return copy
    }

    func starting(at date: Date) -> Tournament {
        var copy = self
        copy.status = .inProgress
        copy.startedAt = date
        copy.updatedAt = date
        return copy
    }

    func completing(winnerEntryId: String, at date: Date) -> Tournament {
        var copy = self
        copy.status = .completed
        copy.winnerEntryId = winnerEntryId
        copy.completedAt = date
        copy.updatedAt = date
        return copy
    }

    func cancelling(at date: Date) -> Tournament {
        var copy = self
        copy.status = .cancelled
        copy.updatedAt = date
        return copy
    }
}

/// Which slice of tournaments a list shows.
nonisolated enum TournamentScope: Hashable, Sendable {
    /// Public tournaments in registration, soonest first; Explore.
    case upcoming
    /// Every tournament whose room the caller is in; Home.
    case mine
    /// A group's tournaments, by start; its Tournaments segment.
    case group(id: String)
}

/// A tournament's detail, pushed from a card, a tile, a chat's info button or a room row. The name shows until the
/// detail answers, like `UserProfileDestination`; a system row about a match names it, and the detail opens it.
nonisolated struct TournamentDestination: Hashable, Sendable {
    let id: String
    let name: String
    let matchID: String?

    init(id: String, name: String, matchID: String? = nil) {
        self.id = id
        self.name = name
        self.matchID = matchID
    }
}

/// Pushes the Discover tournaments screen; a value with no payload, so a `NavigationLink` can name it.
nonisolated struct DiscoverTournamentsDestination: Hashable, Sendable {}
